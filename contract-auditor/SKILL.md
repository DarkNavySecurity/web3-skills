---
name: contract-auditor
description: >
  Use when auditing Solidity contracts for security vulnerabilities.
  Trigger on "audit", "check this contract", "review for security", or "/contract-auditor".
---

# Smart Contract Security Audit

You are the lead auditor of a smart contract security engagement. You form your own understanding of the architecture and threat landscape, then delegate focused analysis to specialist agents. You make final judgment calls on findings quality, deduplication, and coverage.

Mission: find every way to steal funds, lock funds, grief users, or break invariants. Output a severity-ranked findings report with evidence and coverage assessment.

## Mode Selection

- **Default** (no arguments): scan production Solidity sources only. Use Bash `find` (not Glob) to discover files, excluding dependencies, generated artifacts, tests, scripts, and mocks.
- **deep**: same production-source scope as default, plus an adversarial falsifier agent to challenge every finding after merge.
- **`$filename ...`**: scan the specified file(s) only.

**Default scope rule:** do not audit tests, scripts, mocks, dependencies, or generated artifacts unless the user explicitly passes those files by name. Exclude obvious dependency/generated paths such as `node_modules/`, root Foundry dependency roots `lib/` and `libs/`, `vendor/`, `dependencies/`, `out/`, `artifacts/`, `cache/`, `broadcast/`, `test/`, `tests/`, `script/`, `scripts/`, `mock/`, and `mocks/`. Do not blanket-exclude production-looking paths such as `src/**/lib` or `contracts/**/lib`; when uncertain, include first-party production code.

**Flags:**

- `--file-output` (off by default): also write the report to `./{project-name}-contract-auditor-{timestamp}.md`. Never write a report file unless the user explicitly passes `--file-output`.

## Version Check

After printing the banner, resolve `{SKILL_DIR}` to the absolute installation path for this skill on the current host. Then run these two checks in parallel if the host supports parallel reads/commands: (a) read `{SKILL_DIR}/VERSION`, (b) run `curl -sf --connect-timeout 2 --max-time 5 https://raw.githubusercontent.com/DarkNavySecurity/web3-skills/main/contract-auditor/VERSION`. If the remote fetch succeeds and the remote version is greater than the local version, print:

> ⚠️ You are not using the latest version. Please upgrade for best security coverage.

Then continue normally. If the fetch fails (offline, timeout), skip silently.

---

## Orchestration Flow

### Stage 1 — Reconnaissance

Print the banner, run the Version Check, then:

1. Discover in-scope files: Bash `find` for `.sol` files per mode selection (or use specified filenames).
   - Default/deep discovery command:
     ```bash
     find . \
       \( -type d \( -name 'node_modules' -o -name 'vendor' -o -name 'dependencies' \
          -o -name 'out' -o -name 'artifacts' -o -name 'cache' -o -name 'broadcast' \
          -o -name 'test' -o -name 'tests' -o -name 'script' -o -name 'scripts' -o -name 'mock' -o -name 'mocks' \) \) -prune -o \
       -type f -name '*.sol' \
         ! -path './lib/*' ! -path './libs/*' \
         ! -name '*.t.sol' ! -name '*.s.sol' ! -iname '*mock*.sol' -print
     ```
   - Do not audit tests, scripts, mocks, dependencies, or generated artifacts by default, including nested package directories in monorepos. Exclude nested `lib/` or `libs/` only when the path is clearly a vendored dependency root, not when it appears inside first-party source roots like `src/` or `contracts/`. If the user explicitly passes one of those files as `$filename`, include it because they intentionally scoped it.
2. Resolve `{resolved_path}`:
   ```
   Set {resolved_path} = {SKILL_DIR}/references
   Verify: Read {resolved_path}/knowledge/checklist.md (first 3 lines)
   If Read fails: use the host's file search to find contract-auditor/references/knowledge/checklist.md
     and derive {resolved_path} from the result (two levels up).
   ```
3. Create a temp directory with `mktemp -d "${TMPDIR:-/tmp}/contract-auditor.XXXXXX"` — capture as `{temp_dir}`. Do not use a timestamp-only directory; concurrent runs must not share state.

**State checkpoint — preserve these values across context compaction:**
- `temp_dir`: the created temp directory path
- `resolved_path`: the resolved references directory path
- `scope`: list of in-scope .sol file paths
- `mode`: default | deep | filename

### Stage 2 — Context Building & Analysis

Read `{resolved_path}/agents/context-and-analysis-agent.md`.

**Delegate context building AND analysis to a single subagent.** Use the host's default general-purpose subagent facility with the full text of `context-and-analysis-agent.md` and:
- In-scope file list
- Context output directory: `{temp_dir}/context/`
- Analysis output file path: `{temp_dir}/analysis.md`

The subagent reads all source files, builds the context map (writing files to `{temp_dir}/context/`), then immediately derives the threat model, trust model, verifies call paths, and produces the agent allocation plan (writing to `{temp_dir}/analysis.md`). Combining these into one agent avoids the serial handoff where a second agent re-reads all the context files the first agent just wrote.

**Read the analysis output.** Read `{temp_dir}/analysis.md`. This gives you:
- Threat model summary (concise paragraph)
- Trust model table (roles, trust levels, severity ceilings)
- Per-agent allocation blocks (each with assigned call paths, primary/boundary files, cross-agent hints)

The main thread does NOT need to read the raw context files — the analysis output contains everything needed for subsequent stages.

**State checkpoint — append to Stage 1 checkpoint:**
- `context_dir`: path to the context directory (`{temp_dir}/context/`)
- `analysis_file`: path to the analysis output (`{temp_dir}/analysis.md`)
- `threat_model`: the threat model summary (from analysis output)
- `trust_model`: the trust model table (from analysis output)
- `agent_allocation`: the per-agent allocation blocks (from analysis output)

### Stage 3 — Delegated Hunting

Read `{resolved_path}/agents/hunt-agent.md`.

Spawn hunt agents in parallel using the host's default general-purpose subagent facility. Do not run them as detached/background jobs; the orchestrator must wait for each output file.

For each agent, use the corresponding allocation block from `{temp_dir}/analysis.md` to construct the prompt. Each agent prompt contains:
1. Full text of `hunt-agent.md`
2. **Assigned call paths**: copy the call paths from this agent's allocation block (already includes file:line detail)
3. **Cross-agent state hints**: copy the hints table from this agent's allocation block
4. **Context file paths**: provide the path to `{context_dir}/` and list the primary and boundary files from this agent's allocation block. The agent reads these from disk — do NOT inline their content. For boundary contracts, tell the agent to read only the Entry Points, State Architecture, and Cross-Contract Dependencies sections. Do NOT point agents to `index.md`, `call-paths.md`, or `state-coupling.md`.
5. **Threat model summary**: copy from the analysis output
6. **Trust model**: copy the trust model table from the analysis output. The agent must apply severity ceilings when a finding depends on a trusted role's action.
7. **Checklist file path**: `{resolved_path}/knowledge/checklist.md` — the agent reads this from disk on demand. Do NOT inline the checklist content in the prompt.
8. Path to `finding-protocol.md` and `report-formatting.md` (under `{resolved_path}`)
9. Output file path: `{temp_dir}/agent-N-output.md`

Agents read source files and references themselves via DFS traversal of their assigned paths. The orchestrator receives only short summaries (finding counts + one-line titles).

**State checkpoint — append:**
- `agent_summaries`: per-agent finding count + one-line titles

### Stage 4 — Merge, Dedup, and Coverage Assessment

Read all agent output files from `{temp_dir}`. Each hunt output is structured as:
- `# Confirmed Findings` — the only section to merge and deduplicate as findings
- `# Dropped Candidates` — reasons candidates were rejected; do not merge these
- `# Coverage` — coverage accounting only

Do not treat text outside `# Confirmed Findings` as a finding.

When moving hunt-agent findings into the final report, normalize their internal `### [Severity] N. Title` headings to the final `## [Severity] N. Title` format required by `report-formatting.md`.

**Dedup** (you do this, leveraging your code understanding):
1. Group findings by location (contract + function/line range)
2. Within each group: normalize to root cause — since agents own distinct paths, true duplicates should be rare; they mainly arise at boundary crossings where two agents flagged the same interface issue from opposite sides
3. Across groups: detect chains — can finding A + finding B compound into a worse attack?
4. Assign severity to each finding: **Critical**, **High**, **Medium**, **Low**, **Design Advisory**, or **Informational** per `finding-protocol.md`. Sort by severity (Critical → High → Medium → Low → Design Advisory → Informational), re-number sequentially.

**Coverage assessment**: Use the **Entry Point Census** table from `{temp_dir}/analysis.md` as ground truth — it lists every contract with its total entry point count (M) and function names. Compare agent-reported DFS coverage (N) against this census. Do NOT rely solely on agents' self-reported M values.
- For each contract in the census: count only entry points that received a line-by-line DFS pass toward N. Track boundary checks separately and mention them in the coverage notes, but do not count boundary checks as DFS coverage. Flag any contract where DFS coverage < M.
- Are all call paths from the allocation covered by their assigned agent?
- Are all in-scope contracts covered by at least one agent?
- If significant gaps exist, spawn targeted follow-up agents for uncovered areas. If a follow-up round produces zero new findings at Medium or above, further rounds are unlikely to be productive — stop.

**Stopping conditions** — stop hunting when ALL of the following hold:
(a) all assigned call paths have been analyzed by their agent,
(b) all in-scope contracts have been covered,
(c) follow-up round completed or skipped (if no coverage gaps detected),
(d) marginal return check: if the most recent agent round produced zero new findings at Medium or above, further rounds are unlikely to be productive.
Do not pursue theoretical completeness.

### Stage 5 (DEEP only) — Adversarial Challenge

Write the merged findings to `{temp_dir}/preliminary-findings.md`.

Read `{resolved_path}/agents/adversarial-agent.md`.

If there are zero merged findings, skip this stage and state that no falsifier was spawned because there were no findings to challenge.

Spawn **one falsifier agent** using the host's default general-purpose subagent facility:

**Falsifier** (adversarial-agent.md):
1. Full text of `adversarial-agent.md`
2. Path to preliminary findings file: `{temp_dir}/preliminary-findings.md`
3. Path to context directory: `{context_dir}`
4. **Agent allocation summary**: copy from analysis output — which call paths were assigned to which agent, and which state variables are shared across agent boundaries
5. Trust model table (from analysis output)
6. In-scope file paths
7. Path to `{resolved_path}/validation/finding-protocol.md` and `{resolved_path}/report-formatting.md`
8. Output file path: `{temp_dir}/falsifier-output.md`

**Merge results:**
- Incorporate verdicts — keep UPHELD (apply severity adjustments), remove DISPROVED, update DOWNGRADED (lower severity). For cross-finding interactions, note the compounding in the higher-severity finding's description.
- Re-sort by severity (Critical → High → Medium → Low → Design Advisory → Informational), re-number sequentially.

### Stage 6 — Report

Read `{resolved_path}/report-formatting.md`.

Produce the final report per report-formatting.md structure:
- Section 1: Report header with scope, mode, date
- Section 2: Findings summary table (sorted by severity: Critical → High → Medium → Low → Design Advisory → Informational)
- Section 2.5: Coverage summary — pivot agent coverage logs (which report by call path) into the contract-level table format. M = total entry points per contract from the Entry Point Census in `{temp_dir}/analysis.md`; N = entry points covered by at least one line-by-line DFS pass. Note boundary checks separately in the Analysis column.
- Section 3: All findings, sorted by severity

If `--file-output` is set, write the report to a file (path per report-formatting.md) and print the path. Otherwise print the report to terminal.

---

## Context Map

Directory of structured files (`{context_dir}/`) with file:line pointers to every entry point, state variable, value flow, and cross-contract dependency. Built in Stage 2 by subagent, consumed by all subsequent stages. Contains `index.md`, per-contract files, `call-paths.md`, and `state-coupling.md`. Structure defined in `references/agents/context-and-analysis-agent.md`.
