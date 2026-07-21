# web3-skills

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Immunefi: $22K](https://img.shields.io/badge/Immunefi-$22K-4B275F.svg)](https://immunefi.com/profile/DARKNAVY/)
[![Claude Code｜Codex](https://img.shields.io/badge/Claude_Code\|Codex-Skill-F96854.svg)](https://docs.anthropic.com/en/docs/claude-code)

Web3 security skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Codex](https://openai.com/codex) — smart contract auditing, blockchain client auditing, and on-chain exploit investigation.

## Skills

| Skill | Invoke | Description |
|-------|--------|-------------|
| [**contract-auditor**](./contract-auditor/) | `/contract-auditor [path] [deep]` | Solidity security auditor — DFS-based context mapping, parallel hunt agents, optional adversarial falsifier |
| [**client-auditor**](./client-auditor/) | `/client-auditor <start\|verify\|report> [path]` | Blockchain node auditor (Go, Rust, C/C++) — 20 vulnerability pattern families across P2P, consensus, RPC, and memory safety; three explicit phases with disk-anchored audit state |
| [**exploit-investigator**](./exploit-investigator/) | `/exploit-investigator 0x<tx> <chain>` | On-chain exploit investigator — traces attack transactions, reconstructs exploit logic, Analyst-Validator debate loop, optional Foundry PoC ⚠️ [requires Python env + API keys](./exploit-investigator/README.md#setup) |

### contract-auditor

```bash
/contract-auditor                   # scan production Solidity sources
/contract-auditor deep              # adds adversarial falsifier pass
/contract-auditor src/Vault.sol     # review specific file(s)
```

### client-auditor

Three explicit phases — do not silently chain. Each phase stops after its own completion gate.

```bash
/client-auditor start [path]        # recon + hunt drafts + inventory; stops after findings/ is populated
/client-auditor verify [path]       # verify Medium+ findings in place (frontmatter + ## Verification body)
/client-auditor verify [path] deep  # also run 4 depth lenses + adversarial review
/client-auditor report [path]       # render report.md from existing findings; no validation
```

### exploit-investigator

```bash
/exploit-investigator <tx_hash> <chain>                  # investigate a transaction
/exploit-investigator <tx_hash> eth "suspected oracle manipulation"   # with hints
/exploit-investigator briefs/incident.md                   # from a pre-written brief
/exploit-investigator poc 0x<tx_hash>                      # generate Foundry PoC
```

## Install

**Claude Code|Codex** :

```
Install skills in https://github.com/DarkNavySecurity/web3-skills/
```

Or update an existing install:

```
Update skills in https://github.com/DarkNavySecurity/web3-skills/
```

> **Note:** exploit-investigator requires additional setup (Python environment, API keys). See its [README](./exploit-investigator/README.md#setup).

## Track Record

**Smart Contract Auditing** — $21K earned on [Immunefi](https://immunefi.com/profile/DARKNAVY/)

**Blockchain Client Auditing**
- ~$800 earned on the [Firedancer Immunefi Competition](https://immunefi.com/audit-competition/firedancer-v1-audit-comp/information/)
- $1K earned on [Immunefi](https://immunefi.com/profile/DARKNAVY/) (1 Medium finding)
- Independently discovered a vulnerability in [rippled](https://github.com/XRPLF/rippled) (XRP Ledger), officially acknowledged and patched

**Onchain Exploit Analysis** — 60+ artifacts in [web3-exploit-analysis](https://github.com/DarkNavySecurity/web3-exploit-analysis), also posted on [![X](https://img.shields.io/badge/Defi_Nerd-000000?logo=x&logoColor=white)](https://x.com/Defi_Nerd_sec)

## License

[MIT](./LICENSE)

## Contact

[![X](https://img.shields.io/badge/DARKNAVY-000000?logo=x&logoColor=white)](https://x.com/DarkNavyOrg) [![X](https://img.shields.io/badge/Defi_Nerd-000000?logo=x&logoColor=white)](https://x.com/Defi_Nerd_sec) [![Website](https://img.shields.io/badge/Website-0D123D?logo=googlechrome&logoColor=white)](https://www.darknavy.org/)
