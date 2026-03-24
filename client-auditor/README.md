# Blockchain Client Auditor

A Claude Code skill for systematic security auditing of blockchain node implementations. Covers execution clients, consensus clients, app-chain SDKs, bridges, and any codebase with P2P networking or consensus logic — written in Go, Rust, C/C++, etc.

---

## What it does

The skill runs a **parallelized, pattern-driven audit** modeled on how professional blockchain security firms approach node-level reviews. It:

1. Maps the full attack surface — entry points across P2P, RPC, consensus, transaction processing, and bridge subsystems
2. Detects language and framework once, writes a shared metadata file that all agents read — no redundant re-derivation
3. Checks every entry point against **20 historical vulnerability pattern families** drawn from real bugs across 20+ ecosystems
4. Enforces structured analysis on every state-modifying branch (no "looks safe" skips)
5. Persists agent outputs to disk so Turn 4 merging never depends on context window size
6. Applies a false-positive gate and confidence scoring before reporting anything
7. Optionally runs a **heuristic explorer** for novel bugs outside known patterns
8. Optionally runs **Red Team → Blue Team → Judge** adversarial review on high-severity findings (capped at 5 per run)

Output is a structured markdown report with severity, confidence, trigger scenario, quantitative impact, and remediation for each finding.

---

## Design philosophy

- Every branch is guilty until proven innocent — and every branch you couldn't prove is reported as a finding.
- Prior knowledge structures the search; what it can't reach, the heuristic explores.
- Correct code does what it should. Secure code also refuses what it shouldn't.

---

## Install

Follow the [Claude Code skills installation guide](https://docs.anthropic.com/en/docs/claude-code/skills).

```
Install skill https://github.com/DarkNavySecurity/skills/client-auditor
```

---

## Usage

```
/client-auditor [target-path] [deep]
```

| Argument | Meaning |
|----------|---------|
| `target-path` | Path to audit. Use `.` for the current directory. Required. |
| `deep` | Enables Agent 5 (heuristic explorer) + adversarial review for HIGH findings. Slower; use for thorough reviews. |

**Examples:**

```bash
# Audit the current repo
/client-auditor .

# Audit a specific subdirectory
/client-auditor ./node

# Full deep audit with adversarial review
/client-auditor . deep
```

---

## How it works

```
Turn 1 — Discover
  ├── Detect language, framework, threading model, memory management
  ├── Identify entry points (P2P handlers, RPC endpoints,
  │   tx processors, consensus hooks, bridge relayers)
  ├── Filter applicable pattern families by tech stack
  ├── [guard] Stop with explanation if no entry points found
  ├── [guard] Scope to 2 highest-risk subsystems if >50 entry points
  └── Write language metadata + entry point list to {session_dir}/entrypoints.md

Turn 2 — Prepare
  └── Build 4 agent bundle files (agent instructions +
      shared metadata file + judging criteria + pattern group)

Turn 3 — Scan (parallel)
  ├── Agent 1: P1–P4            (input validation + state consistency)
  ├── Agent 2: P5–P8            (consensus + state correctness)
  ├── Agent 3: P9–P12 + P17–P18 (resource exhaustion + ZK + bridge + memory/concurrency)
  ├── Agent 4: P13–P16 + P19–P20 (charging + replay + precision + wiring + UB + serialization)
  └── Write each agent's complete output to {session_dir}/agent-N-findings.md

Turn 3.5 — Verify and Extend (4 sub-steps)
  ├── Sub-step 1: Coverage check — locate Phase 4 report per agent;
  │              treat absent report as 0% coverage
  ├── Sub-step 2: Gap-fill — one pass maximum; remaining gaps become
  │              COVERAGE-GAP INFO findings, no second pass spawned
  ├── Sub-step 3: Finding verification — trace execution paths with
  │              Read/Grep; remove unsubstantiated findings
  └── Sub-step 4: [deep only] Spawn Agent 5 (heuristic explorer)
                 + adversarial review for top 5 HIGH findings by confidence

Turn 4 — Report
  ├── Read all findings from {session_dir}/ files (not from context window)
  ├── Deduplicate by root cause
  ├── Apply false-positive gate (3 checks, all must pass)
  ├── Sort by confidence within each severity tier
  └── Write report to audit/findings/
```

Every scan agent runs these phases before reporting:
- **Step 0 (Read Language Metadata):** Read the pre-computed language and skipped-pattern list from the shared file — no redundant language re-derivation
- **Phase 0 (Branch Inventory):** Read every state-modifying branch before analysis begins — no "looks harmless" skips
- **Phase 1 (Triage):** Mark each (entry point × pattern) pair as CANDIDATE or N/A
- **Phase 2 (Deep Pass):** 7-step structured analysis on every CANDIDATE pair
- **Phase 3 (Compose):** Format findings with quantitative impact and missing-defense checklist
- **Phase 4 (Coverage Self-Check):** Report branch coverage percentage; gaps below 90% trigger the Turn 3.5 gap-fill pass

---

## Pattern families

| Agent | Group | ID | Name |
|-------|-------|----|------|
| 1 | **Input & state consistency** | P1 | Negative / illegal input triggers unrecoverable panic |
| | | P2 | Error handling defect in batch processing loops |
| | | P3 | EVM compatibility layer impedance mismatch |
| | | P4 | Validator set / staking hook state inconsistency |
| 2 | **Consensus & state correctness** | P5 | Vote / signature deduplication failures |
| | | P6 | Non-determinism in consensus-path execution |
| | | P7 | RPC handler crash via malformed request |
| | | P8 | Fee grant and fee deduction errors |
| 3 | **Resource, integrity & memory** | P9 | P2P resource exhaustion (DoS without rate limit) |
| | | P10 | Bridge / cross-layer message integrity |
| | | P11 | Unbounded compute in consensus paths |
| | | P12 | ZK circuit under-constraint |
| | | P17 | Memory safety (C/C++ and unsafe Rust) |
| | | P18 | Concurrency and data races |
| 4 | **Correctness at boundaries** | P13 | Charge ordering and gas accounting errors |
| | | P14 | Replay and double-spend |
| | | P15 | Precision loss and rounding manipulation |
| | | P16 | Wiring failures (handler registered to wrong route) |
| | | P19 | Undefined / implementation-defined behavior |
| | | P20 | Serialization boundary hardening |

Patterns are filtered per codebase: no EVM → P3 skipped; no ZK circuits → P12 skipped; safe Rust/Go → P17 skipped; single-threaded runtime → P18 skipped; etc. The orchestrator determines this in Turn 1 and writes it to the shared metadata file — agents use the pre-computed list rather than re-deriving it.

---

## Output format

Each finding includes:

```
Severity    — Critical / High / Medium / Low / Informational
Confidence  — 0–100 score after applying deduction table
Pattern     — P1–P20 family that matched
Location    — file:line_start–line_end
Entry point — how an attacker reaches this code
Description — what the code does, what it fails to do, attacker outcome
Trigger     — step-by-step attack scenario
Quantitative impact — cost × rate × messages = total; time to impact
Existing mitigations — every partial defense, with effectiveness
Missing defenses     — what should be here but isn't
Recommendation       — concrete fix with code location reference
Adversarial review   — [deep only] Red/Blue/Judge verdict table
```

The report opens with an executive summary (scope, finding counts by severity, key conclusions) and closes with a branch coverage appendix listing any areas the automated scan could not fully analyze.

---

## Severity and confidence

**False-positive gate** — three checks, all must pass before a finding is scored:
1. Concrete execution path traceable from attacker input to invariant break
2. Entry point reachable by an external actor (peer, RPC caller, tx submitter)
3. No existing guard already prevents the attack

**Confidence deductions** (start at 100, subtract applicable):

| Condition | Deduction |
|-----------|-----------|
| Requires admin/operator privileges | −30 |
| Requires compromise of a hardened trusted-party key | −40 |
| Requires >33% Byzantine validators | −25 |
| Requires non-default configuration | −20 |
| Feature gated behind undeployed activation / hard fork | −15 |
| Impact is self-contained | −15 |
| Existing partial mitigation present | −10 |
| Sustained attack >1 hour required | −10 |
| Input rejected by deserialization before vulnerable code | −40 |
| No current exploit path (latent / future risk only) | −50 |

**Severity thresholds:**

| Severity | Criteria | Confidence |
|----------|----------|------------|
| Critical | Chain halt, chain split, or fund loss by any peer | ≥80, chain-wide impact |
| High | Node DoS from any peer, significant state corruption | ≥70 |
| Medium | Requires non-default config, or partial DoS, or partial mitigations | 40–69 |
| Low | Theoretical with significant practical constraints | 20–39 |
| Info | Design observation, defense-in-depth suggestion | <20 |

---

## Scope

**Works well on:**
- Execution clients (e.g., go-ethereum, Erigon, Reth, Nethermind, Besu)
- Consensus clients (e.g., Lighthouse, Prysm, Teku, Nimbus, Lodestar)
- App-chain SDKs (e.g., Cosmos SDK, Substrate, Tendermint/CometBFT)
- Custom chains and L2 node implementations
- Bridge and relayer codebases
- Codebases with P2P networking, RPC servers, or consensus logic in any language

**Notes:**
- On codebases with more than 50 entry points, the skill scopes to the two highest-risk subsystems by default; pass a specific subdirectory path to target a different area
- Deep mode is significantly slower; budget extra time for large codebases
- Adversarial review is capped at 5 findings per run (highest confidence first); remaining HIGH findings are reported at initial severity
- The orchestrator runs on whichever model you have; Opus is recommended for Agent 5 and adversarial review agents (deep mode) — Sonnet handles all other turns well
- Cryptographic implementation correctness (e.g., ZK proof soundness) requires specialist review beyond what automated pattern matching can guarantee
- The audit covers code reachable from identified entry points; dead code and disabled feature flags are noted but not deeply analyzed

---

## Deep mode

`deep` activates two additional stages after the initial scan:

**Agent 5 — Heuristic Explorer:** Surveys code *not* covered by the branch inventory from Agents 1–4, looking for bugs that don't fit the 20 known patterns. Uses structural suspicion (state machines without explicit invariant enforcement), complexity signals (unexpectedly long functions, reimplemented stdlib operations), temporal assumptions (ordering dependencies without enforcement), and cross-boundary data flow (trust boundary crossings without validation checkpoints).

**Adversarial review:** For HIGH findings with confidence ≥70, a single agent runs three sequential passes per finding and returns all outputs in one response:
- *Red Team:* Construct the cheapest realistic attack, challenge every claimed defense, produce a quantitative attack model
- *Blue Team:* Inventory all existing mitigations, assess attack cost and detection probability, reassess impact realism
- *Judge:* Verify every factual claim from both teams against the actual source code, recalculate severity using only verified facts, render TRUE / PARTIAL / FALSE verdict

Capped at 5 findings per run, prioritized by confidence score. The Judge's verdict replaces the initial severity in the final report; findings beyond the cap are noted as not adversarially reviewed.
