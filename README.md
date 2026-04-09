# web3-skills

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Immunefi: $22K](https://img.shields.io/badge/Immunefi-$22K-4B275F.svg)](https://immunefi.com/profile/DARKNAVY/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-F96854.svg)](https://docs.anthropic.com/en/docs/claude-code)

Web3 security skills kit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — smart contract auditing, blockchain client auditing, and on-chain exploit investigation.

## Skills

| Skill | Description |
|-------|-------------|
| [**contract-auditor**](./contract-auditor/) | DFS-based multi-agent audit for Solidity — context mapping, parallel hunt agents, adversarial validation |
| [**client-auditor**](./client-auditor/) | 7-stage orchestrated audit for blockchain node codebases (Go, Rust, C/C++, etc) with 20 vulnerability pattern families |
| [**exploit-investigator**](./exploit-investigator/) | Multi-agent pipeline for on-chain attack analysis with Analyst-Validator debate loop and optional Foundry PoC |

## Track Record

**Smart Contract Auditing** — $21K earned on [Immunefi](https://immunefi.com/profile/DARKNAVY/)

**Blockchain Client Auditing**
- $1K earned on [Immunefi](https://immunefi.com/profile/DARKNAVY/) (1 Medium finding)
- Independently discovered a vulnerability in [rippled](https://github.com/XRPLF/rippled) (XRP Ledger), officially acknowledged and patched

**Onchain Exploit Analysis** — 40+ Artifacts in [web3-exploit-analysis](https://github.com/DarkNavySecurity/web3-exploit-analysis), also posted on [![X](https://img.shields.io/badge/Defi_Nerd-000000?logo=x&logoColor=white)](https://x.com/Defi_Nerd_sec)

## Install

Tell Claude Code:

```
Install skill https://github.com/DarkNavySecurity/web3-skills/
```

Or clone manually:

```bash
git clone https://github.com/DarkNavySecurity/web3-skills.git
bash web3-skills/install.sh
```

> **Note:** exploit-investigator requires additional setup (Python environment, API keys). See its [README](./exploit-investigator/README.md#setup) for details.

## Update

```
Update skill https://github.com/DarkNavySecurity/web3-skills/
```

## License

[MIT](./LICENSE)

## Contact

[![X](https://img.shields.io/badge/DARKNAVY-000000?logo=x&logoColor=white)](https://x.com/DarkNavyOrg) [![X](https://img.shields.io/badge/Defi_Nerd-000000?logo=x&logoColor=white)](https://x.com/Defi_Nerd_sec) [![Website](https://img.shields.io/badge/Website-0D123D?logo=googlechrome&logoColor=white)](https://www.darknavy.org/)