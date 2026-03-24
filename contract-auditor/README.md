# contract-auditor

A methodology-driven AI security auditor (for Solidity currently, pending for Move, Rust, etc.). Four specialized agents hunt in parallel — each with a different analysis dimension and heuristics — then findings are merged, deduplicated, and validated.

Built for:

- **Solidity devs** who want a security check before every commit
- **Security researchers** looking for fast wins before a manual review
- **Just about anyone** who wants an extra pair of eyes.

Not a substitute for a formal audit — but the check you should never skip.

## Design philosophy

Pattern knowledge tells you where bugs have been. Methodology tells you where bugs hide. This skill runs both in parallel.

Four agents hunt simultaneously, each with a different analysis dimension — not a different slice of the codebase. Every agent sees the full code and the full entry-point map, but applies a different lens:

| Agent | Specialization |
|-------|---------------|
| 1 | Discovery & Composability — external interactions, anomaly detection, economic game theory |
| 2 | State Integrity & Value Flow — invariant breaking, state propagation, value flow tracing |
| 3 | Vulnerability Pattern Matching — standard vulnerability classes, token behavior matrix, zero/sentinel analysis |
| 4 | Boundaries & Cross-Contract — delegation boundaries, cross-contract interactions, mechanism matrices |

Each agent's pass file encodes structured heuristics — not a checklist to tick off, but a methodology to follow. When a heuristic flags something, the agent pulls from a shared vulnerability knowledge base for deeper pattern matching.

Every finding passes through a structured validation protocol (3-gate + 6D adversarial scoring) before it reaches the report.

DEEP mode adds an architectural context pass (trust boundaries, invariants, complexity hotspots) and an adversarial reasoning agent that challenges every finding with a 6-check falsification protocol.

## Usage

```bash
# Scan the full repo (default — 4 phases)
/contract-auditor

# Full pipeline: context building + adversarial reasoning (6 phases, slower)
/contract-auditor deep

# Review specific file(s)
/contract-auditor src/Vault.sol
/contract-auditor src/Vault.sol src/Router.sol

# Write report to a markdown file (terminal-only by default)
/contract-auditor --file-output
```

> Knowledge base informed by community research including [smart-contract-auditing-heuristics](https://github.com/OpenCoreCH/smart-contract-auditing-heuristics) and [smart-contract-vulnerabilities](https://github.com/kadenzipfel/smart-contract-vulnerabilities).