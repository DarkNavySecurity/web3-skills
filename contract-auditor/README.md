# contract-auditor

A DFS-based AI security auditor for Solidity. The lead auditor reads code, builds a structured context map, extracts value-flow call paths, then delegates each path to a hunt agent for line-by-line depth-first analysis. Findings are merged, deduplicated, and validated.

Built for:

- **Solidity devs** who want a security check before every commit
- **Security researchers** looking for fast wins before a manual review
- **Just about anyone** who wants an extra pair of eyes

Not a substitute for a formal audit — but the check you should never skip.

## Design philosophy

The model is already a strong reasoner. The skill doesn't try to think for it — it ensures the model **sees everything** and **knows the domain patterns**, then gets out of the way.

**Coverage, not constraint** — The biggest failure mode of AI auditing isn't wrong reasoning — it's missing code. An agent that never reads a function can't find a bug in it. The skill's primary job is structural: build a context map of every entry point, every state variable, every value flow, every cross-contract call. Group paths by state coupling so no shared mutable variable falls between agent boundaries. Track coverage against a ground-truth census so gaps are caught, not assumed away. The reasoning within each path is the model's to do freely.

**Domain knowledge as a reference, not a script** — The checklist is a curated set of Solidity vulnerability patterns (reentrancy, precision loss, access control gaps, oracle manipulation, etc.) that agents read from disk and consult when they encounter a matching code pattern. It tells the agent *what to check for* when it sees a division or an external call — it doesn't tell it *what to conclude*. The agent's own judgment drives whether something is a finding, a design choice, or a false alarm.

**Validation as discipline, not gatekeeping** — Every finding passes through a structured protocol (3-gate + 6D adversarial scoring) to prevent hallucinated vulnerabilities. DEEP mode adds a falsifier agent that challenges every finding with source-level verification. The goal is precision — not suppressing the model's instincts, but requiring it to show its work.

## Usage

```bash
# Scan the full repo
/contract-auditor

# Deep: adds adversarial falsifier after merge
/contract-auditor deep

# Review specific file(s)
/contract-auditor src/Vault.sol
/contract-auditor src/Vault.sol src/Router.sol

# Write report to a markdown file (terminal-only by default)
/contract-auditor --file-output
```

> Knowledge base informed by community research including [smart-contract-auditing-heuristics](https://github.com/OpenCoreCH/smart-contract-auditing-heuristics) and [smart-contract-vulnerabilities](https://github.com/kadenzipfel/smart-contract-vulnerabilities).