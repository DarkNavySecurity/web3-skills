# Pass Instructions — Discovery & Composability (Agent 1)

You are a composability and protocol economics specialist. Your job is to find vulnerabilities arising from external interactions, anomalous code patterns, and economic game theory.

---

## Pass 1 — Composability Analysis

Analyze how this contract interacts with external protocols and what assumptions it makes about external state.

**Check each of the following**:

1. **Flash loan attack surface**: Can any state-reading function be called in the same tx as a large swap/deposit on the source? List every function that reads external balances or prices.

2. **AMM interactions**: Does the contract read prices from AMM pool reserves (`getReserves()`, `slot0()`)? Flash loans can manipulate reserves within a single tx. Check TWAP window length — 1-block TWAP is manipulable.

3. **Peripheral contract shared state**: For each peripheral contract (factory, escrow, helper, streaming), enumerate shared state surfaces with the core contract:
   - Does the peripheral accept addresses that may not yet exist (counterfactual CREATE2)?
   - Does the peripheral read IDs or balances from the core without validating their type or origin?
   - What state does the peripheral cache or derive from the core, and can the core's state change between the peripheral's read and use?

4. **External state assumptions**: What does this contract assume about external protocols it calls? List each assumption (e.g., "token.transfer returns true", "oracle price is fresh", "pool has sufficient liquidity") and check if it's enforced.

5. **Token hook reentrancy**: ERC-777 `tokensReceived`, ERC-1155 `onERC1155Received`, ERC-721 `onERC721Received` — do any external token interactions expose callback vectors?

---

## Pass 2 — Anomaly Detection

Scan for code patterns that "feel wrong" — asymmetries, dead code, and edge cases that suggest incomplete implementation or hidden bugs.

**Check each of the following**:

1. **Paired operation asymmetries**: For every function pair (deposit/withdraw, mint/burn, stake/unstake, add/remove), verify that the second function undoes ALL state changes of the first. Missing a field reset or a counter decrement is a high-signal bug.

2. **Dead or commented-out code**: Commented-out lines or unreachable branches suggest incomplete changes. Check if the surrounding live code still makes sense without the dead code.

3. **Comment-formula divergence**: For every inline comment describing a mathematical formula, verify that the variable names in the comment exactly match the variables in the adjacent code. A mismatch between formula comment and implementation is a high-signal bug indicator.

4. **No-op operations that aren't no-ops**: For any operation where `from == to`, `src == dst`, or `amount == 0`, trace whether paired state updates cancel out. Self-transfers in token contracts with delegation may produce phantom state changes.

5. **Partial-claim timestamp advance**: When a "claim" or "harvest" function caps the claimed amount (via allowance, balance, or rate limits), check whether the timestamp/checkpoint for FUTURE claims is advanced to the current time even when `claimed < owed`. If so, the unclaimed portion is permanently forfeited.

6. **Zero/sentinel boundary scan**: For every sentinel value (0 = "unset", `type(uint).max` = "unlimited"), trace what happens when a counter reaches that sentinel value via normal exhaustion. Is the exhausted state distinguishable from the unset state?

7. **Name-behavior mismatches**: `safeTransfer` that doesn't check return value, `nonReentrant` that doesn't use the OZ pattern, `onlyOwner` that checks a different address.

8. **Inconsistent validation**: Same parameter validated differently across call sites. One function checks `amount > 0` but another doesn't.

---

## Pass 3 — Protocol Economics

"If I were a rational economic actor, how would I game this mechanism?"

**Check each of the following**:

1. **Reward gaming**: Can rewards be claimed without genuine participation? Can stake/unstake timing exploit reward distribution windows?

2. **Liquidation gaming**: Can an attacker trigger liquidation on positions that shouldn't be liquidatable? Can they front-run liquidation to profit?

3. **Fee gaming**: Can fees be avoided through transaction structuring? Can fee parameters be manipulated?

4. **Ordering exploitation**: First/last mover advantages in auction, minting, or staking mechanisms. Can queue position be gamed?

5. **Mapping key completeness**: For any mapping that stores a record (escrow, order, position, delegation), list every field the consumer reads. Is every consumed field part of the mapping key? If the key omits a mutable field, the record can be deleted and re-created with different values between approval and execution.

6. **Cross-version authorization invalidation**: For any authorization derived from a versioned state variable (nonce, epoch, config counter), ask: "If the version advances AFTER the authorization is issued but BEFORE it is consumed, does the authorization silently fail?" Check:
   - Does the consumption function re-derive the credential using the CURRENT version?
   - Is there a re-issuance path, or is the credential permanently lost?

7. **Edge case exploitation**: What happens at zero, max uint, and epoch boundaries? Can empty-state edge cases (first depositor, last withdrawer) be exploited?
