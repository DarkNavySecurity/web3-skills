# contract-auditor

A DFS-based AI security auditor for Solidity. The lead auditor reads code, builds a structured context map, extracts value-flow call paths, then delegates each path to a hunt agent for line-by-line depth-first analysis. Findings are merged, deduplicated, and validated.

Built for:

- **Solidity devs** who want a security check before every commit
- **Security researchers** looking for fast wins before a manual review
- **Just about anyone** who wants an extra pair of eyes

Not a substitute for a formal audit — but the check you should never skip.

## Install

Follow the [root install instructions](../README.md#install), which installs all skills including this one.

## Usage

```bash
# Scan production Solidity sources
/contract-auditor

# Deep: adds adversarial falsifier after merge
/contract-auditor deep

# Review specific file(s)
/contract-auditor src/Vault.sol
/contract-auditor src/Vault.sol src/Router.sol

# Write report to a markdown file (terminal-only by default)
/contract-auditor --file-output
```

By default, repo-wide scans exclude common dependency, generated, test, script, and mock paths (`node_modules/`, `lib/`, `test/`, `script/`, `mock/`, `out/`, `artifacts/`, etc.). Pass specific filenames when you intentionally want those files reviewed.

Use default mode for quick pre-merge checks. Use `deep` for high-value code, contest submissions, or final review passes where extra adversarial validation is worth the additional time.

## Pipeline

```
1. Reconnaissance    → discover .sol files, resolve skill references, create temp dir
2. Context & Analysis → subagent builds context map + threat model + agent allocation plan
3. Delegated Hunting → parallel hunt agents do DFS on assigned call paths
4. Merge & Dedup     → deduplicate findings, assess coverage against entry point census
5. Adversarial [deep] → falsifier agent challenges every finding with source verification
6. Report            → severity-ranked findings + honest coverage summary
```

The orchestrator (main context) coordinates and validates but delegates all source code reading to subagents, keeping context lean for large codebases.

## Output

By default the report is printed to terminal. With `--file-output`, it is also written to `./{project-name}-contract-auditor-{timestamp}.md`.

The report includes:
- **Findings summary table** — sorted by severity (Critical / High / Medium / Low / Design Advisory / Informational)
- **Detailed findings** — each with location, root cause, attack scenario, impact, existing mitigations, and recommended fix
- **Coverage summary** — entry points analyzed vs. total, per contract, with notes on what was and wasn't covered

Each finding passes a **3-gate false-positive check** (concrete execution path, external reachability, no sufficient existing guard) and **6D adversarial scoring** before inclusion.

## Scope and limitations

- Targets Solidity codebases (`.sol` files)
- Works on single files, multi-file projects, and monorepos
- Handles proxy patterns, cross-contract calls, and complex inheritance
- Excludes tests, scripts, mocks, dependencies, and generated artifacts from default scans
- Deep mode is slower — budget extra time for the adversarial falsifier pass
- Formal verification and cryptographic implementation correctness are out of scope

## Design philosophy

The model is already a strong reasoner. The skill doesn't try to think for it — it ensures the model **sees production code paths**, **tracks coverage**, and **knows the domain patterns**, then gets out of the way.

**Coverage, not constraint** — The skill builds a context map of every in-scope entry point, state variable, value flow, and cross-contract call. Grouping paths by state coupling keeps shared mutable variables from falling between agent boundaries.

**Domain knowledge as a reference, not a script** — The checklist is a curated set of Solidity vulnerability patterns that agents consult when they encounter matching code: value flow, MEV/order risk, low-level/storage layout, transient storage (EIP-1153), account delegation (EIP-7702), governance/admin risk, time/randomness, liveness/DoS, signatures, and token integration. It tells the agent what to check, not what to conclude.

**Validation as discipline, not gatekeeping** — Every finding passes a structured validation protocol before inclusion. `deep` mode adds a falsifier agent that challenges every finding with source-level verification.

## References

Knowledge base informed by community research including [smart-contract-auditing-heuristics](https://github.com/OpenCoreCH/smart-contract-auditing-heuristics) and [smart-contract-vulnerabilities](https://github.com/kadenzipfel/smart-contract-vulnerabilities). Legacy taxonomy IDs are intentionally not used; the skill distills concrete exploit patterns into operational checks.
