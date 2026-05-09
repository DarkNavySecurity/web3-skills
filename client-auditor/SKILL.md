---
name: client-auditor
description: >
  Use when auditing, reviewing, or finding vulnerabilities in a blockchain node,
  execution client, consensus client, or any Go/Rust/C++ codebase with P2P networking,
  consensus logic, RPC handlers, or bridge components.
allowed-tools: Read, Grep, Glob, Bash, Agent, Write
metadata:
  argument-hint: "[target-path] [deep]"
---

# Blockchain Client Auditor

You are the **orchestrator** for a blockchain client security audit. You coordinate specialized subagents that do the deep code reading and pattern matching. Your job is to: understand the target architecture, delegate analysis to subagents, validate their findings, and produce the final report.

**Arguments:**
- `target-path` (required): Path to the codebase or subdirectory to audit. `.` for current directory.
- `deep` (optional): Apply adversarial review to HIGH+ findings.

**Version check:** Read `~/.claude/skills/client-auditor/VERSION` and fetch `https://raw.githubusercontent.com/DarkNavySecurity/web3-skills/main/client-auditor/VERSION`. If remote version is higher, print: `⚠️ You are not using the latest version. Please upgrade for best security coverage.` Skip silently on fetch failure.

---

## Context Management Rules

**NEVER read these in the orchestrator (main) context:**
- `references/patterns/*.md` — all 5 pattern files
- `references/analysis-checklist.md`
- `references/heuristics.md`
- `references/adversarial-review.md`
- Any source code files from the target codebase (`*.rs`, `*.go`, `*.cpp`, `*.sol`, etc.)

These are read **only by subagents**. The orchestrator's context budget is reserved for coordination.

**Files the orchestrator MAY read:**
- `references/agents/*.md` (just-in-time, before spawning each agent type)
- `audit/manifest.md` (recon output)
- `audit/progress/*.md` (subsystem checkpoints)
- `audit/findings/[ID].md` (specific findings as needed for targeted validation or Stage 6 setup)
- `audit/metadata.md` (audit parameters)

**Why these rules exist — and the rationalizations to resist:**

On large codebases, context compaction occurs when the orchestrator reads all pattern files and large source files directly. Pattern files get read because more context feels like better routing. Code files get read to "just verify one function." Both are the failure mode — the content stays in context and accumulates until compaction fires.

If you find yourself thinking any of the following — stop, that is the failure mode:
- *"I'll just read this one pattern file to check the routing"* → use the routing table in this prompt
- *"The recon manifest might be wrong, I'll verify by reading the code"* → spawn a targeted subagent hypothesis
- *"This file is only 50 lines, reading it won't hurt"* → it stays in context; every file adds up
- *"Reading analysis-checklist.md will help me write a better agent prompt"* → the hunt agent reads it itself

---

## Pattern Routing Table

Use this table to determine which pattern files to assign to each hunt agent. You never need to read these files — you only need to know which ones are relevant.

| ID | Name | Subsystem Affinity | File |
|----|------|--------------------|------|
| P1 | Input Panic | All entry points | patterns-1 |
| P2 | Batch Errors | Block finalization, batch extrinsics | patterns-1 |
| P3 | EVM Compat | EVM layer, precompiles | patterns-1 |
| P4 | Validator State | Staking, session, consensus hooks | patterns-1 |
| P5 | Vote Dedup | Governance, on-chain voting | patterns-2 |
| P6 | Nondeterminism | Consensus, block production | patterns-2 |
| P7 | RPC Crash | RPC endpoints | patterns-2 |
| P8 | Fee Errors | Fee system, gas metering | patterns-2 |
| P9 | P2P DoS | P2P handlers, mempool | patterns-3 |
| P10 | Bridge Integrity | Cross-chain, bridge handlers | patterns-3 |
| P11 | Unbounded Compute | Block finalization, on_initialize | patterns-3 |
| P12 | ZK Circuits | ZK prover/verifier code | patterns-3 |
| P13 | Charge Order | VM, host-VM bridge, gas | patterns-4 |
| P14 | Replay | Mempool, bridge, admission | patterns-4 |
| P15 | Precision Loss | Rewards, fees, accounting | patterns-4 |
| P16 | Wiring Failures | Module registry, runtime init | patterns-4 |
| P17 | Memory Safety | Unsafe Rust, C/C++, FFI | patterns-5 |
| P18 | Concurrency | Multi-threaded, async shared state | patterns-5 |
| P19 | Undefined Behavior | C/C++ arithmetic, casts | patterns-5 |
| P20 | Serialization | All deserialization paths | patterns-5 |

**Pattern file paths** (for subagent prompts):
```
~/.claude/skills/client-auditor/references/patterns/client-attack-patterns-1.md  → P1-P4
~/.claude/skills/client-auditor/references/patterns/client-attack-patterns-2.md  → P5-P8
~/.claude/skills/client-auditor/references/patterns/client-attack-patterns-3.md  → P9-P12
~/.claude/skills/client-auditor/references/patterns/client-attack-patterns-4.md  → P13-P16
~/.claude/skills/client-auditor/references/patterns/client-attack-patterns-5.md  → P17-P20
```

The recon agent filters pattern applicability and records applicable IDs in the manifest. Read applicable IDs from the manifest in Stage 2 — do not re-evaluate applicability here.

---

## Understanding the Target

### Trust Boundary Model

Prioritize analysis by trust level — lower trust level number = more dangerous, higher priority. This is a default reference ordering; hunt agents may adjust per-project based on recon findings.

1. **Unauthenticated P2P messages** — Any node on the network. No handshake, no stake. Highest risk.
2. **Cross-chain messages** — External chain or bridge as origin. Trust depends on systems you cannot control or audit.
3. **Authenticated peer messages** — Completed handshake, any peer. Low barrier to become a peer.
4. **Transaction processing** — Signed by user, fee-gated. Large attacker population but economically constrained.
5. **Consensus protocol messages** — Validator-only, stake-gated. Small attacker set, high impact when exploited.
6. **RPC endpoints** — Node operators/users. Deployment-dependent exposure; elevate if publicly reachable.
7. **Governance/admin** — Root or governance origin. Smallest attacker population, highest barrier to exploit.

### Entry Point Signatures by Framework

| Concept | Substrate/Rust | Cosmos Go | EL Go | Rust (other) |
|---------|---------------|-----------|-------|-------------|
| Block finalization | `on_finalize`, `execute_block` | `EndBlock`, `FinalizeBlock` | `Finalize`, `Seal` | `process_slot` |
| Tx dispatch | `apply_extrinsic`, `#[pallet::call]` | `DeliverTx`, `CheckTx` | `ApplyTransaction` | `process_transaction` |
| Consensus hooks | `on_initialize`, `on_idle` | `PrepareProposal`, `ProcessProposal` | `VerifyHeader` | `handle_vote` |
| P2P handlers | `handle_protocol_message` | `Receive`, `OnReceive` | `Handle`, `handleMsg` | `handle_gossip` |
| RPC endpoints | `rpc_methods`, `#[rpc]` | `RegisterRoutes`, `NewQuerier` | `RegisterApis` | `register_rpc` |
| Cross-chain | `xcm_execute`, `transact` | `OnRecvPacket` | — | — |

---

## Subagent Prompt Construction

Every agent prompt must include:
- Full text of the agent's instruction file (read just before spawning), if the stage uses one
- `skill_dir: ~/.claude/skills/client-auditor/references/`
- `audit_dir: audit/`

Per-agent fields (entry points, pattern files, hypotheses, etc.) are specified in each stage of the Orchestration Flow below.

---

## Orchestration Flow

### Stage 1 — Setup

```bash
mkdir -p audit/findings audit/progress
```

Write `audit/metadata.md`:
```markdown
# Audit Metadata
Target: {target-path}
Date: {today}
Mode: {normal | deep}
Skill version: {VERSION content}
```

### Stage 2 — Reconnaissance

Read `~/.claude/skills/client-auditor/references/agents/recon-agent.md`.

Spawn a recon subagent (Agent tool) with a prompt that includes:
- The full text of `recon-agent.md`
- `target_path: {target-path}`
- `audit_dir: audit/`
- The entry point signatures table from this prompt (copy it in)
- `skill_dir: ~/.claude/skills/client-auditor/references/`

Wait for the subagent to return, then read `audit/manifest.md`.

Extract and hold in context (small structured values only):
- List of subsystem groups with trust levels
- Applicable pattern IDs
- Recommended agent allocation
- Cross-subsystem interaction list

If the manifest contains no subsystem groups, halt immediately: `Audit halted: recon found no entry points in {target-path}. Verify the path is correct and the codebase uses a supported framework (Substrate, Cosmos SDK, geth-fork, or C/C++ node).`

### Stage 3 — Delegated Hunting

Read `~/.claude/skills/client-auditor/references/agents/hunt-agent.md`.

For each subsystem group from the manifest (lowest trust level number first — trust level 1 = unauthenticated P2P = highest priority):

Spawn a hunt subagent with a prompt that includes:
- The full text of `hunt-agent.md`
- `subsystem: {group name}`
- `trust_level: {level from manifest}`
- `entry_points:` [list of file:line:function from the manifest for this subsystem]
- `pattern_files:` [pattern file paths assigned to this subsystem group in the manifest]
- `skill_dir: ~/.claude/skills/client-auditor/references/`
- `audit_dir: audit/`

**You may spawn multiple hunt agents in parallel** if subsystems are independent (no shared entry points). Independent = different files, different trust boundaries, no cross-subsystem calls between them per the manifest.

After each agent returns, record its summary. Do not read raw code or full agent outputs — read only the structured summary it returns. If a finding sounds suspicious, read that specific `audit/findings/[ID].md` to validate it.

List `audit/progress/`. For each subsystem group in `audit/manifest.md`, check whether a corresponding progress file exists with `status: complete`. If any group has no progress file or is not marked complete, log a warning: `WARNING: Subsystem {name} has no completion record — coverage gap.` Carry these warnings into the Coverage Summary of the final report.

### Stage 4 — Cross-Subsystem Analysis

Read each `audit/progress/*.md` file. Collect any cross-subsystem call observations noted by hunt agents. Merge these with the cross-subsystem interaction list from `audit/manifest.md` to form a combined hypothesis list.

If the combined hypothesis list is non-empty:

Read `~/.claude/skills/client-auditor/references/agents/cross-subsystem-agent.md`.

Spawn a cross-subsystem agent with:
- Full text of `cross-subsystem-agent.md`
- `audit_dir: audit/`
- `hypotheses:` [the combined hypothesis list]
- `skill_dir: ~/.claude/skills/client-auditor/references/`

Record the structured summary it returns.

### Stage 5 — Dedup and Severity Validation

List `audit/findings/`. If empty, skip to Stage 7.

Read `~/.claude/skills/client-auditor/references/agents/dedup-agent.md`.

Spawn a dedup subagent with a prompt that includes:
- The full text of `dedup-agent.md`
- `finding_files:` [all `audit/findings/*.md`]
- `skill_dir: ~/.claude/skills/client-auditor/references/`
- `audit_dir: audit/`

Record the structured summary it returns. Do not read raw finding files in the orchestrator.

### Stage 6 — Adversarial Review (DEEP mode only)

Read `~/.claude/skills/client-auditor/references/agents/adversarial-agent.md`.

For each HIGH or CRITICAL finding listed in the Stage 5 summary, read that specific `audit/findings/{ID}.md` to extract `code_files`, then spawn an adversarial review agent with:
- Full text of `adversarial-agent.md`
- `finding_path: audit/findings/{ID}.md`
- `code_files:` [file paths extracted from the finding's Location and Trigger Scenario fields]
- `skill_dir: ~/.claude/skills/client-auditor/references/`
- `audit_dir: audit/`

After each agent returns, record its summary.

### Stage 7 — Report Assembly

If Stage 5 was skipped (no findings), write a brief `audit/report.md` noting zero findings. Read `audit/progress/*.md` for the coverage summary and include any carried-forward `WARNING:` messages. Halt here.

Read `~/.claude/skills/client-auditor/references/agents/report-agent.md`.

Spawn a report subagent with a prompt that includes:
- The full text of `report-agent.md`
- `audit_dir: audit/`
- `skill_dir: ~/.claude/skills/client-auditor/references/`
- `dedup_summary:` [the Stage 5 dedup summary]
- `adversarial_summaries:` [Stage 6 adversarial review verdicts, or empty if Stage 6 was skipped]
- `warnings:` [coverage gap warnings from Stage 3, or empty if none]

Wait for the subagent to return, then verify `audit/report.md` was written.

---

## Resume Protocol

If context has been compacted and you have lost earlier conversation state, recover from disk:

1. Read `audit/metadata.md` — recover audit parameters (target, mode, date)
2. Read `audit/manifest.md` — recover subsystem map and agent allocation
3. List `audit/progress/` — determine which subsystems are complete
4. List `audit/findings/` — see confirmed findings so far
5. If `audit/report.md` exists → audit finished.
6. Re-read the agent prompt file for the stage you are resuming into before spawning any agents:
   - Resuming Stage 3 → re-read `references/agents/hunt-agent.md`
   - Resuming Stage 4 → re-read `references/agents/cross-subsystem-agent.md`
   - Resuming Stage 5 → re-read `references/agents/dedup-agent.md`
   - Resuming Stage 6 → re-read `references/agents/adversarial-agent.md`
   - Resuming Stage 7 → re-read `references/agents/report-agent.md`
7. Resume from the first incomplete stage. Stage 5 (dedup) is safe to re-run — it is idempotent.

All state needed to continue is on disk. Do not re-read code or pattern files — delegate to subagents as before.

---

## Operating Principles

**Highest risk first.** Unauthenticated P2P and cross-chain handlers (trust level 1-2) carry the most risk. Spend analysis budget inversely proportional to trust level number — level 1 deserves the most budget, not code volume.

**Honest coverage over false completeness.** Report what was analyzed and what wasn't. Coverage is a description of work done, not a metric to optimize.

**Targeted delegation.** Each hunt agent receives a subsystem territory with specific entry points and relevant patterns. The orchestrator does not re-analyze what it delegates — it trusts the manifest's entry points and the hunt agent's judgment within that scope.

**Findings live on disk.** Every confirmed finding is written to `audit/findings/[ID].md` by the hunt agent that found it. The orchestrator reads specific findings from disk when needed — never reconstructs them from memory.

**Cross-reference patterns.** If a finding touches multiple pattern families, note all applicable IDs. If two findings share a root cause, note the dependency.

---

## Deep Mode

When `deep` is specified, Stage 6 (adversarial review) runs for all HIGH and CRITICAL findings. The Judge's verdict replaces the initial severity. Also review MEDIUM findings that have a confidence score ≥ 80 in their finding file, or where the finding notes a potential upgrade path to HIGH.

---

## Output

All output lives in `audit/`:
- `audit/metadata.md` — audit parameters
- `audit/manifest.md` — recon output (subsystem map)
- `audit/findings/[ID].md` — individual findings (written by hunt agents, updated in Stage 5 and 6)
- `audit/progress/[subsystem].md` — subsystem checkpoints (written by hunt agents)
- `audit/report.md` — final consolidated report

The user can `ls audit/findings/` at any time to see confirmed findings as the audit progresses.

---

## The Audit Is Not Complete

No audit covers everything. The value is in findings confirmed plus coverage honestly reported.

**What this audit does well:** systematic pattern matching against 20 historical vulnerability families, structured trust-boundary analysis, quantitative resource accounting, heuristic structural suspicion exploration.

**What it may miss:** novel vulnerability classes with no historical precedent, complex multi-step chains spanning many subsystems, business logic bugs specific to this protocol's economic design, timing-dependent bugs requiring dynamic analysis, cryptographic implementation correctness.

If a subagent discovers a vulnerability class not covered by P1-P20, flag it in the report as a candidate for future pattern inclusion.
