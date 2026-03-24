# Vulnerability Knowledge Base

Quick-reference for known smart contract vulnerability patterns. Organized by category with detection heuristics, code patterns, and false positive indicators. For deep-dive references, Read the corresponding file from `knowledge/vulnerabilities/` via the index in `kb-index.md`.

---

## Category 1: Reentrancy

### 1.1 Single-Function Reentrancy

**What goes wrong**: Contract makes an external call (ETH transfer, token transfer, callback) before updating state. Callee re-enters the same function and exploits stale state.

**Detection heuristic**:
- Find all external calls: `.call()`, `.transfer()`, `.send()`, `safeTransferFrom()`, `_safeMint()`, `_safeTransfer()`
- Check if state is written AFTER the call (violations of Checks-Effects-Interactions)
- Check for missing `nonReentrant` modifier

**Vulnerable pattern**:
```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];
    (bool success,) = msg.sender.call{value: amount}("");  // external call
    require(success);
    balances[msg.sender] = 0;  // state update AFTER call
}
```

**Fixed pattern**:
```solidity
function withdraw() external nonReentrant {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;  // state update BEFORE call
    (bool success,) = msg.sender.call{value: amount}("");
    require(success);
}
```

**False positive indicators**: `nonReentrant` modifier present; state updated before call; token is standard ERC-20 without hooks.

### 1.2 Cross-Function Reentrancy

**What goes wrong**: Function A makes an external call; attacker re-enters via Function B which reads state that Function A hasn't finished updating.

**Detection heuristic**:
- Find external calls in Function A
- Check if ANY other function reads state that Function A modifies after the call
- Check if `nonReentrant` is on BOTH functions (same guard instance)

**Key insight**: `nonReentrant` on Function A alone doesn't prevent re-entry into Function B unless they share the same ReentrancyGuard storage slot.

### 1.3 Cross-Contract Reentrancy (Read-Only)

**What goes wrong**: Contract A makes external call before updating state. Attacker re-enters Contract B (not A) which reads A's stale state. A's `nonReentrant` doesn't protect B.

**Detection heuristic**: Find contracts that read state from other contracts. Check if the source contract has external calls before updating that state.

### 1.4 Hidden Reentrancy Vectors

Callbacks that trigger reentrancy beyond obvious `.call()`:
- ERC-777 `tokensReceived` hook
- ERC-1155 `onERC1155Received` / `onERC1155BatchReceived`
- ERC-721 `onERC721Received` (via `_safeMint`, `safeTransferFrom`)
- `permit()` followed by `transferFrom()` in same tx
- Arbitrary callback in flash loan `execute()` functions

---

## Category 2: Oracle / Price Manipulation

### 2.1 AMM Spot Price as Oracle

**What goes wrong**: Contract reads price from AMM pool reserves (e.g., Uniswap `getReserves()`). Flash loan can manipulate reserves within a single tx.

**Detection heuristic**:
- Search for `getReserves()`, `slot0()`, `observe()`, `consult()`
- Check if price is derived from pool balance ratios
- Check if TWAP window is too short (1-block TWAP is manipulable)

### 2.2 Stale Oracle Data

**What goes wrong**: Chainlink `latestRoundData()` called without checking `updatedAt` timestamp.

**Detection heuristic**:
- Find `latestRoundData()` calls
- Check if `updatedAt` or `answeredInRound` is validated
- Check if `answer <= 0` is handled
- Check for sequencer uptime feed on L2s

### 2.3 Decimal Mismatch

**What goes wrong**: Oracle returns price in different decimals than the token uses. USDC has 6 decimals but Chainlink ETH/USD has 8.

**Detection heuristic**: Check all price feed decimals against token decimals. Look for missing `10 ** (decimalsA - decimalsB)` scaling.

---

## Category 3: Precision / Rounding

### 3.1 Division Before Multiplication

**What goes wrong**: Integer division truncates. Dividing before multiplying loses precision.

**Detection heuristic**:
- Search for arithmetic expressions with division
- Flag if division appears before multiplication in the same expression
- Check if numerator can be smaller than denominator (truncates to zero)

### 3.2 Rounding Direction

**What goes wrong**: Rounding always favors one party. In share-based systems, rounding should favor the protocol (round down shares on deposit, round down assets on withdraw).

**Detection heuristic**: In ERC-4626 vaults, check `convertToShares` and `convertToAssets` rounding direction.

### 3.3 First Depositor / Inflation Attack

**What goes wrong**: When `totalShares == 0`, first depositor gets 1:1 shares. Attacker deposits 1 wei, donates tokens to inflate share price, then subsequent depositors get 0 shares due to truncation.

**Detection heuristic**:
- Check if vault mints dead shares in constructor
- Check if virtual offset is used (OpenZeppelin ERC-4626 pattern)
- Check for `totalSupply == 0` special case in share calculation

### 3.4 Zero Amount Edge Cases

**What goes wrong**: Functions don't validate `amount > 0`. Zero-amount operations may update timestamps, reset accumulators, or trigger events without meaningful state change.

**Detection heuristic**: Check if deposit/withdraw/transfer/mint/burn functions have `require(amount > 0)`.

---

## Category 4: Access Control

### 4.1 Missing Access Control

**What goes wrong**: State-changing functions lack `onlyOwner`, `onlyRole`, or inline `require(msg.sender == ...)` checks.

**Detection heuristic**:
- List ALL `external`/`public` state-changing functions
- Check each for access control modifiers or inline checks
- Pay special attention to: `setFee()`, `setOwner()`, `mint()`, `burn()`, `pause()`, `upgrade()`, `initialize()`

### 4.2 Unprotected Initializer

**What goes wrong**: `initialize()` on an upgradeable contract lacks `initializer` modifier, or the implementation contract is left uninitialized.

**Detection heuristic**:
- Find `initialize()` functions
- Check for `initializer` modifier (OpenZeppelin)
- Check if implementation contract calls `_disableInitializers()` in constructor

### 4.3 tx.origin Authorization

**What goes wrong**: `tx.origin` returns the EOA that initiated the transaction. Phishing contract can call the victim's function while `tx.origin == victim`.

**Detection heuristic**: Search all `tx.origin` usage. Flag if used in `require()` or `if` for authorization.

### 4.4 Default Visibility

**What goes wrong**: In Solidity <0.5.0, functions without explicit visibility default to `public`.

**Detection heuristic**: Check Solidity version. If <0.5.0, search for functions without visibility keywords.

---

## Category 5: Front-Running / MEV

### 5.1 Transaction-Ordering Dependence

**What goes wrong**: Transaction inputs visible in mempool. Attackers front-run or sandwich profitable transactions.

**Detection heuristic**:
- DEX swaps without slippage protection (`minAmountOut`, `deadline`)
- On-chain secret submissions without commit-reveal
- ERC-20 `approve()` race condition
- Auction/bidding where order determines winner

### 5.2 Sandwich Attacks

**What goes wrong**: Attacker front-runs a swap to move price, victim executes at worse price, attacker back-runs to profit.

**Detection heuristic**: Check if swap functions have `minAmountOut` AND `deadline` parameters that are validated.

---

## Category 6: Inflation / Share Manipulation

### 6.1 Donation Attack

**What goes wrong**: Attacker sends tokens directly to a contract (bypassing deposit function) to inflate `balanceOf(address(this))` without updating internal accounting.

**Detection heuristic**:
- Check if contract uses `token.balanceOf(address(this))` as source of truth vs. internal `totalAssets` variable
- Check if `receive()` / `fallback()` functions accept ETH that gets counted in accounting

---

## Category 7: Flash Loan Amplification

### 7.1 Governance Flash Loan

**What goes wrong**: Attacker flash-borrows governance tokens, votes on a proposal, then repays. Bypasses governance's assumption that voters have long-term stake.

**Detection heuristic**: Check if governance uses snapshot voting or if voting power is read at current block.

### 7.2 Price Manipulation via Flash Loan

**What goes wrong**: Flash-borrowed liquidity manipulates AMM reserves, oracle prices, or collateral ratios within a single transaction.

**Detection heuristic**: Check if any price-reading function can be called in the same tx as a large swap/deposit on the price source.

---

## Category 8: DoS

### 8.1 Unbounded Loop

**What goes wrong**: Loop iterates over a dynamic, user-growable array. When array grows large enough, function exceeds block gas limit.

**Detection heuristic**:
- Find all `for`/`while` loops
- Check if iteration count depends on dynamic storage array
- Check if array can grow without bound

### 8.2 Unexpected Revert

**What goes wrong**: Push-payment pattern where one reverting recipient blocks all payments. Force-sent ETH breaks strict balance equality checks.

**Detection heuristic**:
- Search for loops with `require(success)` on external calls
- Search for strict balance equality (`==` with `address(this).balance`)

### 8.3 Unbounded Return Data

**What goes wrong**: Low-level `.call()` to untrusted address copies ALL return data to memory. Attacker returns megabytes, causing OOG.

**Detection heuristic**:
- Find `.call()` / `.delegatecall()` / `.staticcall()` to untrusted addresses
- Check if return data is bounded (assembly with fixed-size buffer)

---

## Category 9: Logic Errors

### 9.1 Off-By-One

**What goes wrong**: Loop boundaries or threshold comparisons off by exactly one. `length - 1` on empty array underflows to max uint.

**Detection heuristic**:
- For each loop: verify `< length` vs `<= length` vs `< length - 1`
- Flag `length - 1` on arrays that could be empty

### 9.2 Incorrect Inheritance Order

**What goes wrong**: C3 linearization resolves rightmost parent first. Wrong order causes unintended function resolution.

### 9.3 Shadowing State Variables

**What goes wrong**: Child contract redeclares parent's state variable, creating two separate storage slots. Parent functions use parent's slot.

**Detection heuristic**: In Solidity <0.6.0, search for state variable names in both parent and child.

---

## Category 10: Composability (DeFi-Specific)

### 10.1 Fee-On-Transfer Tokens

**What goes wrong**: Contract assumes `amount` parameter equals tokens received.

**Detection heuristic**:
- Check if contract uses balance-before/balance-after pattern
- If not: check if token whitelist includes fee-on-transfer tokens (PAXG, etc.)

### 10.2 Rebasing Tokens

**What goes wrong**: Rebasing tokens change balances without transfers. Contract's internal accounting diverges from actual balance.

### 10.3 ERC-777 / Token Hooks

**What goes wrong**: ERC-777 tokens call `tokensReceived` on recipient, enabling reentrancy.

### 10.4 msg.value Reuse in Loops

**What goes wrong**: `msg.value` is constant throughout transaction. In loops, the same ETH value is "spent" multiple times.

**Detection heuristic**:
- Search `msg.value` inside `for`/`while` loops
- Check for `msg.value` in functions callable via `multicall` / `delegatecall` batching

---

## Category 11: Signature Vulnerabilities

### 11.1 Signature Replay

**What goes wrong**: Signed message lacks nonce, contract address, or chain ID. Can be replayed across contexts.

**Detection heuristic**:
- Find `ecrecover` or `ECDSA.recover` calls
- Check signed hash includes: nonce, `address(this)`, `block.chainid`
- Check for EIP-712 domain separator

### 11.2 Signature Malleability

**What goes wrong**: ECDSA signature `(r, s)` has complementary form `(r, n-s)`. If deduplication tracks raw signature bytes, attacker submits the complement.

**Detection heuristic**:
- Search for `mapping(bytes => bool)` tracking used signatures
- Check if `s` is validated to be in lower half of curve order

### 11.3 ecrecover Returns address(0)

**What goes wrong**: Invalid signature parameters cause `ecrecover` to return `address(0)`. Compared against uninitialized variable passes.

### 11.4 Hash Collision with abi.encodePacked

**What goes wrong**: `abi.encodePacked()` with multiple variable-length arguments concatenates without length prefixes.

**Detection heuristic**:
- Search `abi.encodePacked(` calls
- Flag if 2+ adjacent arguments are variable-length (`string`, `bytes`, dynamic arrays)
- Check if result feeds into `keccak256` for security purposes

---

## Category 12: Execution Context

### 12.1 Delegatecall to Untrusted Callee

**What goes wrong**: `delegatecall` executes code in the caller's storage context. User-controlled target = storage overwrite.

**Detection heuristic**:
- Search all `delegatecall` invocations
- Trace target address: hardcoded? immutable? user-influenced?

### 12.2 Arbitrary Storage Write

**What goes wrong**: User-controlled array indices allow computing offsets that write to any storage slot.

### 12.3 Uninitialized Storage Pointer

**What goes wrong**: In Solidity <0.5.0, local structs without explicit data location default to storage at slot 0.

---

## Category 13: Low-Level Call Safety

### 13.1 Unchecked Return Values

**What goes wrong**: `.call()`, `.send()`, `.delegatecall()` return bool indicating success. Not checking it means execution continues after silent failure.

### 13.2 Calls to Non-Existent Contracts

**What goes wrong**: EVM treats calls to addresses with no code as successful.

### 13.3 Unsafe .transfer() on Non-Mainnet

**What goes wrong**: `.transfer()` and `.send()` forward only 2300 gas. On chains with different gas pricing, this is insufficient.

---

## Category 14: Randomness

### 14.1 Weak On-Chain Randomness

**What goes wrong**: "Random" values from `block.timestamp`, `blockhash`, `block.prevrandao` are deterministic. Another contract in same tx computes identical value.

**Detection heuristic**:
- Search for `block.timestamp`, `block.prevrandao`, `block.difficulty`, `blockhash` fed into `keccak256`
- Check if result has economic impact

---

## Category 15: Compiler / Language

### 15.1 Integer Overflow/Underflow

**What goes wrong**: In Solidity <0.8.0 or `unchecked` blocks, arithmetic wraps silently.

**Still vulnerable in >=0.8.0**: `unchecked` blocks, inline assembly arithmetic, type downcasts (`uint8(x)`), shift operators.

### 15.2 Floating Pragma

**What goes wrong**: `pragma solidity ^0.8.0` allows any 0.8.x compiler with potential bugs.

### 15.3 Unsupported Opcodes on L2s

**What goes wrong**: PUSH0 (Solidity >=0.8.20) not supported on all chains. zkSync has different CREATE/CREATE2 behavior.

---

## Category 16: Data Exposure

### 16.1 Private Data On-Chain

**What goes wrong**: Solidity `private` only prevents other contracts from reading. Anyone can read via `eth_getStorageAt`.

---

## Quick Reference: Solidity Version Thresholds

| Version | Significance |
|---------|-------------|
| <0.4.22 | Constructor by name (typo = public function) |
| <0.5.0 | Default function visibility `public`; uninitialized storage pointers; `.length` writable |
| <0.6.0 | State variable shadowing allowed |
| <0.8.0 | No built-in overflow protection |
| >=0.8.0 | Safe arithmetic (except `unchecked`, assembly, casts, shifts) |
| >=0.8.20 | PUSH0 opcode — may not work on all chains |

## Quick Reference: Token Assumption Checklist

| Assumption | Tokens That Break It |
|------------|---------------------|
| Transfer amount == received amount | Fee-on-transfer (PAXG, STA) |
| Balance doesn't change without transfer | Rebasing tokens (stETH, AMPL) |
| No hooks/callbacks on transfer | ERC-777, ERC-1155 |
| Decimals are 18 | USDC (6), WBTC (8), GUSD (2) |
| Transfer returns true | USDT (returns nothing) |
| Transfer of 0 succeeds | BNB (reverts on 0) |
| No block/pause on transfers | Pausable tokens, blacklist tokens (USDC, USDT) |

## Quick Reference: Common Guard Patterns

| Guard | What It Protects | Bypass Vector |
|-------|-----------------|---------------|
| `nonReentrant` (OZ) | Same-contract reentrancy | Cross-contract reentrancy into a different contract |
| `whenNotPaused` | Emergency pause | Direct call to unprotected dependency |
| `onlyOwner` | Admin functions | Owner key compromise, unprotected initializer |
| `initializer` (OZ) | One-time init | Calling init on implementation (not proxy) |
| Solidity 0.8+ overflow | Arithmetic overflow | `unchecked`, assembly, type casts |
| `SafeERC20` | Non-standard token returns | Doesn't protect against fee-on-transfer or rebasing |
| `require(success)` on `.call()` | Silent failure | Doesn't protect against returnbomb |
