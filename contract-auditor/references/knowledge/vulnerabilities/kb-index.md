# Vulnerability Knowledge Base Index

Reference files for deep-dive detection heuristics. Each file contains: Preconditions, Vulnerable Pattern, Detection Heuristics, False Positives, and Remediation.

**Usage**: Agents receive this index in their bundle. When a pass identifies a potential vulnerability matching one of these categories, Read the specific file for detailed detection guidance.

---

## Reentrancy & Callbacks

| File | Description |
|------|-------------|
| `reentrancy.md` | Single-function, cross-function, and cross-contract reentrancy via external calls and token hooks |
| `delegatecall-untrusted-callee.md` | Delegatecall to user-controlled address overwrites caller storage |

## Access Control

| File | Description |
|------|-------------|
| `insufficient-access-control.md` | Missing or weak access control on state-changing functions |
| `authorization-txorigin.md` | Authorization via tx.origin enables phishing attacks |
| `default-visibility.md` | Functions without explicit visibility default to public in Solidity <0.5.0 |
| `incorrect-constructor.md` | Misnamed constructor becomes public function (Solidity <0.4.22) |

## Arithmetic & Precision

| File | Description |
|------|-------------|
| `overflow-underflow.md` | Integer overflow/underflow in unchecked blocks, assembly, and type casts |
| `lack-of-precision.md` | Division before multiplication, truncation to zero, rounding direction errors |
| `off-by-one.md` | Boundary errors in loop indices, comparisons, and array access |

## Input Validation & Logic

| File | Description |
|------|-------------|
| `assert-violation.md` | Improper use of assert() for input validation vs invariant checking |
| `requirement-violation.md` | Missing or incorrect require() checks on function inputs |
| `hash-collision.md` | Hash collision via abi.encodePacked() with adjacent variable-length arguments |
| `inadherence-to-standards.md` | Deviations from EIP/ERC specifications breaking composability |

## External Calls & Low-Level Operations

| File | Description |
|------|-------------|
| `unchecked-return-values.md` | Ignoring return values from .call(), .send(), .delegatecall() |
| `unsafe-low-level-call.md` | Low-level calls to addresses with no code succeed silently |
| `unbounded-return-data.md` | Untrusted callee returns megabytes, causing OOG via memory expansion |
| `insufficient-gas-griefing.md` | Forwarding insufficient gas to sub-calls causing silent failure |
| `asserting-contract-from-code-size.md` | extcodesize check bypassed during constructor execution |

## Denial of Service

| File | Description |
|------|-------------|
| `dos-gas-limit.md` | Unbounded loops over user-growable arrays exceed block gas limit |
| `dos-revert.md` | Push-payment pattern where one reverting recipient blocks all payments |

## Signature & Cryptography

| File | Description |
|------|-------------|
| `missing-protection-signature-replay.md` | Signed messages lacking nonce, contract address, or chain ID |
| `signature-malleability.md` | ECDSA (r, s) has complementary form (r, n-s) bypassing signature-based deduplication |
| `unexpected-ecrecover-null-address.md` | Invalid signature parameters cause ecrecover to return address(0) |
| `unsecure-signatures.md` | Weak signature schemes and missing signature validation |

## State & Storage

| File | Description |
|------|-------------|
| `arbitrary-storage-location.md` | User-controlled array indices allow writing to any storage slot |
| `uninitialized-storage-pointer.md` | Local structs without explicit data location default to storage slot 0 (Solidity <0.5.0) |
| `shadowing-state-variables.md` | Child contract redeclares parent state variable creating two storage slots |
| `unencrypted-private-data-on-chain.md` | Private variables readable via eth_getStorageAt |
| `unused-variables.md` | Unused variables indicating incomplete logic or dead code |

## Frontrunning & MEV

| File | Description |
|------|-------------|
| `transaction-ordering-dependence.md` | Mempool-visible transactions enabling frontrunning and sandwich attacks |
| `timestamp-dependence.md` | Miner-manipulable block.timestamp used for critical logic |
| `weak-sources-randomness.md` | On-chain "randomness" from block attributes is deterministic and predictable |

## Token & Value Handling

| File | Description |
|------|-------------|
| `msgvalue-loop.md` | msg.value constant across loop iterations enabling payment bypass |

## Compiler & Deployment

| File | Description |
|------|-------------|
| `floating-pragma.md` | Unlocked pragma allowing compilation with buggy compiler versions |
| `outdated-compiler-version.md` | Using compiler versions with known vulnerabilities |
| `incorrect-inheritance-order.md` | C3 linearization resolving wrong parent due to inheritance order |
| `unsupported-opcodes.md` | Opcodes unavailable on target chain (PUSH0 on L2s, CREATE2 on zkSync) |
| `use-of-deprecated-functions.md` | Using deprecated Solidity functions with known issues |
