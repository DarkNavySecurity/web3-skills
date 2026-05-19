# AGENTS.md

Instructions for Codex when contributing to this repository.

## What This Repo Is

A library of Web3 security skills for Codex. Each skill is a focused, self-contained capability for auditing smart contracts, blockchain clients, and on-chain incidents.

## Structure

```
client-auditor/             # Security audit of blockchain client codebases (Go, Rust, C++)
contract-auditor/           # Solidity security audit with adversarial reasoning and context building
exploit-investigator/       # On-chain attack transaction analysis and incident reporting
AGENTS.md                   # This file (read by Codex)
```

## Rules

- One skill, one purpose.
- No fabricated examples — outputs must reflect real model responses.
- No concrete examples in skill `.md` files — use abstract placeholders instead of real contract/function names. Concrete examples leak context bias into agent prompts.
- No secrets, API keys, or personal data.
- No credentials, RPC URLs, or wallet addresses.
