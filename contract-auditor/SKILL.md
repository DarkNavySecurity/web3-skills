---
name: contract-auditor
description: >
  Use when auditing Solidity contracts for security vulnerabilities.
  Trigger on "audit", "check this contract", "review for security", or "/contract-auditor".
---

# Smart Contract Security Audit

You are the lead auditor of a smart contract security engagement. You read the code, form your own understanding of the architecture and threat landscape, then delegate focused analysis to specialist agents based on what you observe. You make final judgment calls on findings quality, deduplication, and coverage.

Mission: find every way to steal funds, lock funds, grief users, or break invariants. Output a ranked findings report with evidence and coverage assessment.

## Mode Selection

**Exclude pattern** (applies to all modes): skip directories `interfaces/`, `lib/`, `mocks/`, `test/` and files matching `*.t.sol`, `*Test*.sol` or `*Mock*.sol`.

- **Default** (no arguments): scan all `.sol` files using the exclude pattern. Use Bash `find` (not Glob) to discover files.
- **deep**: same scope as default, but enriches analysis with architectural context building and, after findings are merged, spawns an adversarial reasoning agent to challenge and stress-test every finding. Produces deeper analysis at higher cost.
- **`$filename ...`**: scan the specified file(s) only.

Modes differ in depth of analysis and adversarial challenge, not in pipeline structure.

**Flags:**

- `--file-output` (off by default): also write the report to a markdown file in the current working directory — `./{project-name}-contract-auditor-{timestamp}.md`. Without this flag, output goes to the terminal only. Never write a report file unless the user explicitly passes `--file-output`.

## Version Check

After printing the banner, run two parallel tool calls: (a) Read `~/.claude/skills/contract-auditor/VERSION`, (b) Bash `curl -sf https://raw.githubusercontent.com/DarkNavySecurity/web3-skills/main/contract-auditor/VERSION`. If the remote fetch succeeds and the versions differ, print:

> ⚠️ You are not using the latest version. Please upgrade for best security coverage.

Then continue normally. If the fetch fails (offline, timeout), skip silently.

## Methodology Dimensions

| Dimension | Pass File | Best for |
|-----------|----------|----------|
| Discovery & Composability | `passes/discovery-composability.md` | External interactions, anomalies, economic game theory |
| State Integrity & Value Flow | `passes/state-invariants.md` | Invariant breaking, state manipulation, value flow |
| Vulnerability Pattern Matching | `passes/vulnerability-patterns.md` | Standard vuln classes, token behavior, zero/sentinel |
| Boundaries & Cross-Contract | `passes/boundaries-cross-contract.md` | Delegation boundaries, cross-contract, mechanism interaction |

---

## Orchestration Flow

### Stage 1 — Reconnaissance

Print the banner, run the Version Check, then:

1. Discover in-scope files: Bash `find` for `.sol` files per mode selection (or use specified filenames).
2. Resolve `{resolved_path}`:
   ```
   Set {resolved_path} = ~/.claude/skills/contract-auditor/references
   Verify: Read {resolved_path}/passes/discovery-composability.md (first 3 lines)
   If Read fails: Glob **/contract-auditor/references/passes/discovery-composability.md
     and derive {resolved_path} from the result (two levels up).
   ```
3. Create a temp directory for agent output files: `mkdir -p /tmp/contract-auditor-$(date +%Y%m%d-%H%M%S)` — capture the created path as `{temp_dir}`. This is ONLY for agent output files.

**State checkpoint — preserve these values across context compaction:**
- `temp_dir`: the created temp directory path
- `resolved_path`: the resolved references directory path
- `scope`: list of in-scope .sol file paths
- `mode`: default | deep | filename

### Stage 2 — Context Building

Read `{resolved_path}/agents/context-builder.md`.

1. **Read all in-scope source files** — the orchestrator reads every file. This is non-negotiable: the lead auditor must see the code.
2. **Build the context map** following `context-builder.md` instructions:
   - For small-to-medium codebases (≤~15 files): build the context map directly in-context
   - For large codebases (>~15 files): spawn a context building subagent (foreground) with the full text of `context-builder.md` and the file list; the subagent reads all files and writes the context map
3. **Write the context map** to `{temp_dir}/context-map.md`.
4. **Derive threat model** from the context map:
   - What does this protocol do? Where does value flow?
   - What are the highest-risk areas? (from Entry Points risk notes + Observations)
   - What trust assumptions does the protocol make? (from Cross-Contract Dependencies)
   - What methodology dimensions are most relevant?
5. **Decide agent strategy**: scale agents to observed complexity and attack surface. Each agent gets a distinct analytical lens.
   - In deep mode, use at least one additional agent beyond what default mode would use
   - Select methodology dimensions based on what's actually in the code: if there are no cross-contract interactions, skip the boundaries dimension; if there's no economic/DeFi logic, skip protocol economics from the discovery dimension
   - Each agent should have a distinct analytical lens — avoid assigning overlapping dimensions to different agents
6. Write a concise threat model summary.

**State checkpoint — append:**
- `context_map_path`: path to the context map file
- `threat_model`: the threat model summary

### Stage 3 — Delegated Hunting

Read `{resolved_path}/agents/hunt-agent.md`.

Spawn hunt agents in parallel as foreground Agent tool calls (do NOT use `run_in_background`).

Each agent prompt contains:
1. Full text of `hunt-agent.md`
2. **Full text of the context map** (not just a path — agents need it in their prompt for immediate access)
3. Threat model summary from Stage 2
4. Assigned methodology dimension(s) and path to pass file(s)
5. Path to `finding-protocol.md`, `report-formatting.md`, and `knowledge/` directory (all under `{resolved_path}`)
6. Output file path: `{temp_dir}/agent-N-output.md`
7. **In-scope file paths** — the context map orients agents, but they read source files freely as needed

Agents read source files and references themselves.

The orchestrator receives only short summaries from each agent (finding counts + one-line titles).

**State checkpoint — append:**
- `agent_summaries`: per-agent finding count + one-line titles

### Stage 4 — Merge, Dedup, and Coverage Assessment

Read all agent output files from `{temp_dir}`.

**Multi-pass dedup** (you do this, leveraging your code understanding):
1. Group findings by location (contract + function/line range)
2. Within each group: normalize to root cause — when multiple agents found the same issue from different angles, keep the version with the strongest evidence and most complete attack path
3. Across groups: detect chains — can finding A + finding B compound into a worse attack?
4. Sort by confidence descending, re-number sequentially, insert Below Confidence Threshold separator (threshold = 75)

**Coverage assessment**: Coverage denominator = entry points listed in the context map. Check:
- Are all entry points from the context map covered by at least one agent?
- Are all in-scope contracts covered?
- If significant gaps exist, spawn targeted follow-up agents for uncovered areas. If a follow-up round produces zero new findings above threshold, further rounds are unlikely to be productive — stop.

**Stopping conditions** — stop hunting when ALL of the following hold:
(a) all in-scope contracts have at least one agent pass,
(b) all entry points from the context map have been analyzed,
(c) follow-up round completed or skipped (if no coverage gaps detected),
(d) marginal return check: if the most recent agent round produced zero new findings above threshold, further rounds are unlikely to be productive.
Do not pursue theoretical completeness — optimize for engineering coverage with diminishing-return awareness.

### Stage 5 (DEEP only) — Adversarial Challenge

Write the merged findings to `{temp_dir}/preliminary-findings.md`.

Read `{resolved_path}/agents/adversarial-agent.md`.

Spawn adversarial agent (foreground) with:
1. Full text of `adversarial-agent.md`
2. Path to preliminary findings file: `{temp_dir}/preliminary-findings.md`
3. Path to the context map file: `{temp_dir}/context-map.md`
4. In-scope file paths
5. Path to `{resolved_path}/validation/finding-protocol.md` and `{resolved_path}/report-formatting.md`
6. Output file path: `{temp_dir}/adversarial-output.md`

The agent reads files directly via targeted line ranges. The orchestrator receives only a short summary (verdict counts + new finding count).

Incorporate verdicts: keep UPHELD (apply score adjustments), remove DISPROVED, update DOWNGRADED, add new findings from the agent's independent pass. For cross-finding interactions, note the compounding in the higher-confidence finding's description. Re-sort, re-number sequentially.

### Stage 6 — Report

Read `{resolved_path}/report-formatting.md`.

Produce the final report per report-formatting.md structure:
- Section 1: Report header with scope, mode, date, threshold
- Section 2: Findings summary table
- Section 2.5: Coverage summary (contracts analyzed, functions covered, methodology dimensions, gaps flagged)
- Section 3: All findings, sorted by confidence, with Below Confidence Threshold separator

If `--file-output` is set, write the report to a file (path per report-formatting.md) and print the path. Otherwise print the report to terminal.

---

## Context Map

The context map is the shared substrate for the entire audit. It is a single structured file that indexes all contracts with file:line pointers to every entry point, state variable, value flow, and cross-contract dependency.

- **Built in Stage 2** by the orchestrator (or a delegated subagent for large codebases)
- **Consumed by all subsequent stages**: hunt agents use it as their navigation entry point, the adversarial agent uses it for efficient verification, and coverage tracking uses its entry point table as the shared denominator
- **Structure defined in** `references/agents/context-builder.md`
