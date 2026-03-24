---
name: contract-auditor
description: >
  Use when auditing Solidity contracts for security vulnerabilities.
  Trigger on "audit", "check this contract", "review for security", or "/contract-auditor".
---

# Smart Contract Security Audit

You are the orchestrator of a full-pipeline, parallelized smart contract security audit. Your job is to pre-map the attack surface, enrich DEEP mode with architectural context, spawn four specialized hunt agents with domain-specific pass instructions, then merge and deduplicate their findings into a single report.

## Mode Selection

**Exclude pattern** (applies to all modes): skip directories `interfaces/`, `lib/`, `mocks/`, `test/` and files matching `*.t.sol`, `*Test*.sol` or `*Mock*.sol`.

- **Default** (no arguments): scan all `.sol` files using the exclude pattern. Use Bash `find` (not Glob) to discover files.
- **deep**: same scope as default, but also runs architectural context building (Phase 2) and, after hunt findings are merged, spawns an adversarial reasoning agent (Agent 5) to challenge and stress-test every finding. Slower and more costly.
- **`$filename ...`**: scan the specified file(s) only.

**Flags:**

- `--file-output` (off by default): also write the report to a markdown file in the current working directory — `./{project-name}-contract-auditor-{timestamp}.md`. Without this flag, output goes to the terminal only. Never write a report file unless the user explicitly passes `--file-output`.

## Version Check

After printing the banner, run two parallel tool calls: (a) Read `~/.claude/skills/contract-auditor/VERSION`, (b) Bash `curl -sf https://raw.githubusercontent.com/DarkNavySecurity/web3-skills/main/contract-auditor/VERSION`. If the remote fetch succeeds and the versions differ, print:

> ⚠️ You are not using the latest version. Please upgrade for best security coverage.

Then continue normally. If the fetch fails (offline, timeout), skip silently.

## Agent Specializations

Four hunt agents, each with a different analysis dimension:

| Agent | Specialization | Pass File |
|-------|---------------|-----------|
| 1 | Discovery & Composability | `passes/discovery-composability.md` |
| 2 | State Integrity & Value Flow | `passes/state-invariants.md` |
| 3 | Vulnerability Pattern Matching | `passes/vulnerability-patterns.md` |
| 4 | Boundaries & Cross-Contract | `passes/boundaries-cross-contract.md` |

---

## Orchestration — Default and `$filename` modes (4 Phases)

### Phase 1 — Discovery & Attack Surface

Print the banner, run the Version Check, then in the same message make four parallel tool calls:

1. Bash `mkdir -p /tmp/contract-auditor-$(date +%Y%m%d-%H%M%S)` — capture the created path as `{session_dir}`. All intermediate files for this audit session go here.
2. Bash `find` for in-scope `.sol` files per mode selection
3. Resolve `{resolved_path}`:
   ```
   Set {resolved_path} = ~/.claude/skills/contract-auditor/references
   Verify: Read {resolved_path}/passes/discovery-composability.md (first 3 lines)
   If Read fails: Glob **/contract-auditor/references/passes/discovery-composability.md
     and derive {resolved_path} from the result (two levels up).
   ```
4. Spawn EP subagent (foreground, `model: "sonnet"`) using the **EP Subagent Prompt** section below. For `$filename` mode, use the `$filename` variant of the EP subagent prompt (skip `find`, analyze only the specified files).

**State checkpoint — after Phase 1, record these values (preserve across context compaction):**
```
session_dir: /tmp/contract-auditor-YYYYMMDD-HHMMSS
resolved_path: ~/.claude/skills/contract-auditor/references
scope: [list of in-scope .sol file paths]
mode: default | deep | filename
phase: 1 complete
```

### Phase 2 — Bundle Preparation

Read only the files the orchestrator needs for agent prompts and report generation:

1. Read `{resolved_path}/agents/hunt-agent.md`
2. Read `{resolved_path}/report-formatting.md`

Do NOT read `finding-protocol.md`, `vuln-kb.md`, `heuristics.md`, `kb-index.md`, or pass files into orchestrator context — they go into bundles via `cat` only.

Then assemble bundles:

1. Write the EP subagent output verbatim to `{session_dir}/ep-map.md` using the **Write tool** (not Bash heredoc).
2. Bash: in a single command, use `cat` to concatenate files into four per-agent bundle files (`{session_dir}/agent-{1,2,3,4}-bundle.md`) — each contains:

```
{session_dir}/ep-map.md contents
---
All in-scope .sol files (with ### path headers and fenced code blocks)
---
validation/finding-protocol.md
---
report-formatting.md
---
knowledge/vuln-kb.md
---
knowledge/heuristics.md
---
knowledge/vulnerabilities/kb-index.md
---
Agent N's specific pass file (passes/discovery-composability.md / passes/state-invariants.md / passes/vulnerability-patterns.md / passes/boundaries-cross-contract.md)
```

Print line counts for all four files. Every agent receives the same EP map, codebase, validation protocol, knowledge base, and heuristics — only the pass file differs per agent.

### Phase 3 — Parallel Deep Hunting

In a single message, spawn Agents 1–4 as parallel foreground Agent tool calls (do NOT use `run_in_background`).

- **Agents 1–4** (specialized hunt agents) — spawn with `model: "sonnet"`. Each agent prompt must contain the full text of `hunt-agent.md` (read in Phase 2, paste into every prompt). After the instructions, add: `Your bundle file is {session_dir}/agent-N-bundle.md (XXXX lines). Your assigned pass file is at the end of the bundle — it defines your analysis dimension. Write your findings to {session_dir}/agent-N-output.md and return only a short summary.` (substitute the real line count and describe the pass: "Discovery & Composability" / "State Integrity & Value Flow" / "Vulnerability Pattern Matching" / "Boundaries & Cross-Contract").

Agents write their own output files. The orchestrator receives only short summaries (finding counts + titles).

**State checkpoint — after Phase 3, append to the Phase 1 checkpoint:**
```
phase: 3 complete
agent_summaries:
  agent-1: N findings — [score] title, [score] title, ...
  agent-2: N findings — [score] title, [score] title, ...
  agent-3: N findings — [score] title, [score] title, ...
  agent-4: N findings — [score] title, [score] title, ...
```

### Phase 4 — Report

Spawn a merge subagent (foreground, `model: "sonnet"`) with this prompt:

```
You are a findings merge agent. Read these four hunt agent output files in parallel:
- {session_dir}/agent-1-output.md
- {session_dir}/agent-2-output.md
- {session_dir}/agent-3-output.md
- {session_dir}/agent-4-output.md

Also read {resolved_path}/report-formatting.md for the output format.

Merge all findings: deduplicate by root cause — when multiple agents find the same underlying issue from different analysis angles, keep the version with the most complete attack path and highest confidence. Sort by confidence highest-first, re-number sequentially, and insert the Below Confidence Threshold separator row (threshold = 75).

Write the final report to {session_dir}/report.md using the Write tool. Include the scope header (per report-formatting.md) and all findings.

Return only a short summary: total finding count, above/below threshold counts, and one-line titles.
```

The orchestrator receives only the merge summary. If `--file-output` is set, print the report file path. Otherwise, Read `{session_dir}/report.md` and print it to terminal.

---

## Orchestration — DEEP mode (6 Phases)

### Phase 1 — Discovery & Attack Surface

Identical to default Phase 1 — print banner, run Version Check, four parallel calls: `mkdir -p` for `{session_dir}`, `find`, resolve `{resolved_path}`, EP subagent (foreground, sonnet).

**State checkpoint — after Phase 1, record these values (preserve across context compaction):**
```
session_dir: /tmp/contract-auditor-YYYYMMDD-HHMMSS
resolved_path: ~/.claude/skills/contract-auditor/references
scope: [list of in-scope .sol file paths]
mode: deep
phase: 1 complete
```

### Phase 2 — Context Building

In a single message, make parallel tool calls. Only read files the orchestrator itself needs — bundle-only files are assembled via `cat` in Phase 3.

**Orchestrator reads** (needed for agent prompts and report generation):
1. Read `{resolved_path}/agents/hunt-agent.md`
2. Read `{resolved_path}/agents/adversarial-agent.md`
3. Read `{resolved_path}/report-formatting.md`

**Do NOT read** into orchestrator context (these go into bundles via `cat` only):
- `finding-protocol.md`, `vuln-kb.md`, `heuristics.md`, `kb-index.md`, pass files

**Parallel with the reads above:**
4. Spawn context subagent (foreground, `model: "opus"`) using the **Context Subagent Prompt** section below — substitute `{EP_MAP}` with the Phase 1 EP subagent output verbatim and `{FILE_LIST}` with the newline-separated list of in-scope file paths.

### Phase 3 — Bundle Preparation

Assemble bundles:

1. Write the EP subagent output to `{session_dir}/ep-map.md` and the context subagent output to `{session_dir}/context.md` using the **Write tool** (two parallel Write calls, not Bash heredoc).
2. Bash: in a single command, use `cat` to concatenate files into four per-agent bundle files (`{session_dir}/agent-{1,2,3,4}-bundle.md`) — each contains:

```
{session_dir}/ep-map.md contents
---
{session_dir}/context.md contents
---
All in-scope .sol files (with ### path headers and fenced code blocks)
---
validation/finding-protocol.md
---
report-formatting.md
---
knowledge/vuln-kb.md
---
knowledge/heuristics.md
---
knowledge/vulnerabilities/kb-index.md
---
Agent N's specific pass file
```

Print line counts for all four files.

### Phase 4 — Parallel Deep Hunting

In a single message, spawn Agents 1–4 as parallel foreground Agent tool calls (do NOT use `run_in_background`).

- **Agents 1–4** (specialized hunt agents) — spawn with `model: "sonnet"`. Each agent prompt must contain the full text of `hunt-agent.md` (read in Phase 2, paste into every prompt). After the instructions, add: `Your bundle file is {session_dir}/agent-N-bundle.md (XXXX lines). Your assigned pass file is at the end of the bundle — it defines your analysis dimension. Write your findings to {session_dir}/agent-N-output.md and return only a short summary.` (substitute the real line count and describe the pass).

Agents write their own output files. The orchestrator receives only short summaries (finding counts + titles). Do NOT re-read the output files — they are consumed by the merge subagent in Phase 5.

**State checkpoint — after Phase 4, append:**
```
phase: 4 complete
agent_summaries:
  agent-1: N findings — [score] title, [score] title, ...
  agent-2: ...
  agent-3: ...
  agent-4: ...
```

### Phase 5 — Adversarial Challenge

**Step 1 — Merge via subagent.** Spawn a merge subagent (foreground, `model: "sonnet"`) with this prompt:

```
You are a findings merge agent. Read these four hunt agent output files in parallel:
- {session_dir}/agent-1-output.md
- {session_dir}/agent-2-output.md
- {session_dir}/agent-3-output.md
- {session_dir}/agent-4-output.md

Also read {resolved_path}/report-formatting.md for the output format.

Merge all findings: deduplicate by root cause — when multiple agents find the same underlying issue from different analysis angles, keep the version with the most complete attack path and highest confidence. Sort by confidence highest-first, re-number sequentially, and insert the Below Confidence Threshold separator row (threshold = 75).

Write the merged list to {session_dir}/preliminary-findings.md using the Write tool. Format using report-formatting.md structure (findings only — no scope header).

Return only a short summary: total finding count, above/below threshold counts, and one-line titles.
```

The orchestrator receives only the merge summary — it never reads agent 1–4 raw outputs.

**Step 2 — Build Agent 5 bundle.** Bash: use `cat` to concatenate `{session_dir}/preliminary-findings.md`, all in-scope `.sol` files (with `### path` headers and fenced code blocks), `{resolved_path}/validation/finding-protocol.md`, and `{resolved_path}/report-formatting.md` into `{session_dir}/agent-5-bundle.md`; print the line count.

**Step 3 — Spawn Agent 5.** Spawn **Agent 5** (adversarial reasoning) as a single foreground Agent tool call with `model: "opus"`. The agent prompt must contain the full text of `adversarial-agent.md` (read in Phase 2, already in context). After the instructions, add: `Your bundle file is {session_dir}/agent-5-bundle.md (XXXX lines). Write your output to {session_dir}/agent-5-output.md and return only a short summary.` (substitute the real line count).

The orchestrator receives only Agent 5's summary (verdict counts + new finding count).

**State checkpoint — after Phase 5, append:**
```
phase: 5 complete
preliminary: {session_dir}/preliminary-findings.md
  [score] #1 title, [score] #2 title, ... (one line, from merge summary)
agent5_verdict: N upheld, N downgraded, N disproved, N new
agent5_output: {session_dir}/agent-5-output.md
```

### Phase 6 — Report

**Context reload:** Read `{session_dir}/preliminary-findings.md` and `{session_dir}/agent-5-output.md` only. Do NOT re-read `agent-{1,2,3,4}-output.md` — their content is already distilled into the preliminary findings.

Incorporate Agent 5's output into the final report: for UPHELD findings, keep as-is (or apply score adjustments with reason); for DISPROVED findings, remove from the report; for DOWNGRADED findings, update the score and note the reason; for new findings from Agent 5's independent pass, add them; for cross-finding interactions, note the compounding in the higher-confidence finding's description. Re-sort by confidence, re-number sequentially, and insert the **Below Confidence Threshold** separator row. Print findings directly — do not re-draft or re-describe them. Use report-formatting.md (read in Phase 2) for the scope table and output structure. If `--file-output` is set, write the report to a file (path per report-formatting.md) and print the path.

---

## EP Subagent Prompt

Use this prompt verbatim when spawning the EP subagent in Phase 1 of all modes.

```
You are an entry-point analyzer for a Solidity smart contract codebase.

1. Run this find command to discover all in-scope files:
   find . -name '*.sol' -not -path '*/interfaces/*' -not -path '*/lib/*' -not -path '*/mocks/*' -not -path '*/test/*' ! -name '*.t.sol' ! -name '*Test*.sol' ! -name '*Mock*.sol'
2. Read every discovered file in parallel.
3. Extract every externally callable, state-changing function. Exclude `view` and `pure` functions.
4. Classify each function into one of these four categories:
   - Public (Unrestricted): callable by any address with no access restriction
   - Role-Restricted: guarded by a named role (onlyOwner, onlyAdmin, hasRole(X), require(msg.sender == x))
   - Restricted (Review Required): has some access control pattern but not clearly classifiable from the modifier alone
   - Contract-Only: callback or integration hook that reverts for EOA callers (e.g. onERC721Received, flash loan callbacks)
5. Output ONLY the markdown below — no prose, no explanations, no "Files Analyzed" section:

## Entry Point Map

| Category | Count |
|----------|-------|
| Public (Unrestricted) | X |
| Role-Restricted | X |
| Restricted (Review Required) | X |
| Contract-Only | X |
| **Total** | **X** |

### Public (Unrestricted)
- `functionName(params)` — `path/file.sol:L42`
  Note if user-controlled params reach external calls

### Role-Restricted
- `functionName(params)` — `path/file.sol:L15`
  Restriction: `onlyOwner`

### Restricted (Review Required)
- `functionName(params)` — `path/file.sol:L20`
  Pattern: <describe the access control pattern>

### Contract-Only
- `functionName(params)` — `path/file.sol:L30`
  Expected caller: <caller description>
```

**For `$filename` mode:** Replace step 1 with: "Skip the find command. Analyze ONLY these files: [list the specified filenames]. Read them in parallel."

---

## Context Subagent Prompt

Use this prompt verbatim when spawning the context subagent in DEEP Phase 2. Substitute `{EP_MAP}` and `{FILE_LIST}` before sending.

```
You are an architectural context builder for a smart contract security audit. Your output will be injected into security scanner agent bundles — make it precise and useful for identifying vulnerabilities.

DO NOT produce vulnerability findings. Your job is structural context only.

Entry Point Map (from entry-point analysis):
{EP_MAP}

In-scope files:
{FILE_LIST}

Workflow:
1. Read all in-scope .sol files in parallel.
2. For each Public (Unrestricted) entry point: trace the full call chain within the codebase, identify all state variables mutated, note external calls and their ordering relative to state updates.
3. For each Role-Restricted entry point: map what privileged state it can mutate and whether the role restriction is implemented robustly (check the modifier/require body, not just its name).
4. Build a trust boundary map: which contracts are trusted callers, which parameters are user-controlled.
5. Identify protocol invariants: mathematical or logical conditions that must hold at all times (e.g. totalSupply == sum of balances, reserve0 * reserve1 == k).
6. Flag complexity hotspots: functions with 3+ external calls, token transfers that precede state updates, user-controlled call targets, initializer patterns with no caller restriction, emergency paths that bypass normal accounting.

Output ONLY the following markdown structure. Total output must be ≤400 lines. No prose outside the structure below:

## Architecture Context

### Trust Boundaries
- <ContractA> trusts <ContractB> for: [purpose]
- EOA-callable without restriction: [list key public functions]
- User-controlled parameters reaching external calls: [list with function context]

### Key Invariants
- <Contract>: <invariant description>
- ...

### Complexity Hotspots
- `<Contract.function>`: <pattern description> — L<line>
- ...

### Unusual Patterns
- <description of any pattern that deviates from standard Solidity conventions>
- ...
```
