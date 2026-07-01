# Audit Checklist

When you encounter a code pattern below during analysis, execute the corresponding checks. Not a flat list to memorize — a reference to consult when you see the trigger pattern.

---

## External Call / Token Transfer

**Trigger**: `.call()`, `.send()`, `.transfer()`, `safeTransfer`, `safeTransferFrom`, `_safeMint`, `_safeTransfer`, any interface call to another contract

**Reentrancy checks**:
1. Is state written AFTER this external call? If yes → CEI violation
2. Is `nonReentrant` on this function? If no → flag
3. Cross-function: does any other function read state this function modifies after the call? If yes and no shared `nonReentrant` → flag
4. Cross-contract: does another contract read this contract's state that is stale during the call? (A's `nonReentrant` does not protect B)
5. Hidden callbacks: `_safeMint` → `onERC721Received`, ERC-777 → `tokensReceived`, ERC-1155 → `onERC1155Received`, flash loan → `execute()`

**NOT reentrancy when**: state updated before call (CEI correct); `nonReentrant` present; target is trusted immutable (WETH); function is view/pure; token is standard ERC-20 without hooks

**Return value**: is the bool from `.call()`/`.send()` checked? Unchecked = silent failure. (SafeERC20 handles this for token transfers)

**State desync in try/catch**: when a nested call fails inside `try/catch`, check which state persists. Does the outer contract update its state assuming the inner call succeeded? A partial failure can leave two contracts in an inconsistent state.

**Direct access bypass**: if contract A wraps contract B's function with access control, can B be called directly bypassing A's guards? Trace whether the underlying function has its own protection or relies entirely on the wrapper.

**Returnbomb**: if call target is untrusted, Solidity copies ALL return data to memory. Attacker returns megabytes → OOG. Fix: assembly with bounded `returndatacopy`, or `ExcessivelySafeCall`

**Gas griefing**: in relayer/meta-tx patterns, if nonce is marked used BEFORE sub-call and sub-call success is not required, relayer can forward insufficient gas — sub-call fails silently but nonce is consumed, permanently censoring the action. Check: is nonce consumed only after sub-call success? Is there a `gasleft()` minimum before the sub-call?

**Token behavior** (when contract accepts arbitrary/admin-set token addresses):

| Behavior | What breaks | Check |
|----------|------------|-------|
| Fee-on-transfer | received < sent, accounting gap | balance-before/after pattern? |
| Rebasing | balance changes without transfer | internal accounting vs balanceOf? |
| ERC-777 hooks | reentrancy via `tokensReceived` | CEI order + nonReentrant? |
| Blacklistable | transfer reverts, DoS on multi-user ops | single revert blocks batch? |
| Returns false | silent failure without SafeERC20 | using SafeERC20? |
| Zero-amount revert | unexpected revert on 0 transfer | amount validated > 0? |
| Standard mismatch | integrator assumes ERC behavior that token/NFT/vault does not implement | verify return values, hooks, decimals, `preview` vs actual, and zero-address/zero-amount semantics? |

---

## Division / Arithmetic

**Trigger**: `/` operator, `%`, type casts (`uint128(x)`, `uint40(x)`), `unchecked` blocks

1. Division before multiplication? → precision loss. Should be `a * b / c` not `a / c * b`
2. Can numerator < denominator? → truncates to zero. Check `totalSupply == 0` in share calculations
3. Rounding direction: fees/debts should round in favor of protocol (up). Rewards/credits should round in favor of user (down)
4. Amplifiable? Can attacker repeat the operation to compound rounding error?
5. Type cast truncation: `uint40(x)` silently truncates in Solidity ≥0.8 (checked arithmetic does NOT protect casts). `SafeCast` reverts on overflow

6. Comment-formula divergence: when you see inline comments describing a formula, verify the variable names in the comment exactly match the adjacent code. A mismatch between `// fee = amount * rate / total` and actual code `fee = amount / total * rate` is a high-signal bug

**NOT a precision issue when**: `Math.mulDiv` or WAD/RAY scaling used; numerator guaranteed > denominator by prior check; precision loss documented and dust-level

---

## Loop / Iteration

**Trigger**: `for`, `while`, array iteration

1. Unbounded? Can the array grow without limit? If iteration must complete in one tx → DoS at gas limit
2. `msg.value` inside loop? → `msg.value` is constant across iterations. Attacker pays once, loop "spends" it N times
3. `msg.value` in `delegatecall` multicall? → same issue: each sub-call sees the full `msg.value`
4. Push-payment in loop? One reverting recipient blocks all. Prefer pull-payment
5. Off-by-one: `< length` vs `<= length` vs `< length - 1`. The last skips final element; the second goes OOB
6. `length - 1` on empty array → underflows to max uint (reverts in checked arithmetic, wraps in unchecked)

**NOT DoS when**: array is admin-only appendable with practical maximum; function supports pagination/batching; iteration count is caller-controlled with reasonable cap

---

## Revert / DoS Surface

**Trigger**: `require`/custom errors after external input, push payments, batch operations, strict balance equality, arithmetic that can revert, division denominator, callbacks required for progress, liveness-critical keeper/user action

1. **Single-recipient revert blocks all**: if a batch, auction, refund, withdrawal queue, or distribution requires every external transfer/callback to succeed, one reverting recipient can freeze progress. Prefer pull payments, per-recipient failure isolation, or bounded retries.
2. **Unexpected balance**: strict checks like `address(this).balance == expected` or `token.balanceOf(this) == accounting` can be broken by forced ETH or direct ERC-20 transfers. Use internal accounting and tolerate surplus unless surplus is deliberately handled.
3. **Checked arithmetic DoS**: Solidity >=0.8 overflow/underflow reverts. Check small integer types, `length - 1`, decrement-to-zero, signed min negation, and accumulators where a valid state can make future operations revert.
4. **Division by zero**: every denominator derived from external input, oracle output, supply, reserves, elapsed time, or configurable parameters must be proven nonzero before division.
5. **Liveness dependency**: if withdrawals, liquidations, reveals, oracle updates, or finalization depend on one actor calling within a window, ask whether that actor can disappear, be censored, or intentionally delay to lock funds or win value.
6. **Failure state persistence**: when an operation catches or ignores a failed call, verify nonces, checkpoints, debt, queue indexes, and paid flags are not advanced as if the call succeeded.

**NOT a DoS issue when**: the revert affects only the caller's own operation; progress is paginated and resumable; failed recipients can self-serve later; strict balance equality is only an invariant assertion unreachable by external value transfers.

---

## Access Control

**Trigger**: `external`/`public` state-changing function, `initialize()`, `init()`, modifier chain, `tx.origin`, `code.length`, `extcodesize`

1. Does this state-changing function have access control? If no modifier AND no inline `require(msg.sender == ...)` → flag
2. `initialize()` / `init()`: has `initializer` modifier (OZ)? Or custom once-guard? Can be front-run if deploy and init are separate transactions?
3. `_disableInitializers()` in implementation constructor? Without this, anyone can init the implementation directly
4. Role management functions (`grantRole`, `addAdmin`): are they themselves access-controlled?
5. `delegatecall` target: is it user-controlled? If yes → attacker overwrites caller storage

6. **Compliance bypass via auth-transfer**: privileged transfer functions (`authTransfer`, `forceTransfer`) that bypass compliance checks — trace all caller paths upward to external entry points. Can any user-facing function reach the privileged path indirectly? Does the calling contract enforce the compliance checks the bypassed role assumes?
7. **`tx.origin` authorization**: if authorization depends on `tx.origin`, a malicious intermediate contract can call the target while preserving the victim EOA as `tx.origin`. Use `msg.sender` or explicit signed intent instead.
8. **EOA-only gates (post-EIP-7702)**: `msg.sender.code.length == 0`, `tx.origin == msg.sender`, or `extcodesize == 0` neither prove a caller is an EOA nor prove it is codeless. Contracts in construction have zero code length; after EIP-7702 a plain EOA can carry a delegation designator (nonzero code) and execute arbitrary logic when called or when it receives ETH. Treat every external address as potentially code-bearing and re-entrant. See §Account Delegation (EIP-7702).

**NOT access control issue when**: function is intentionally permissionless (deposit, claim); access enforced in internal function called by all paths; atomic deploy+init via proxy constructor `_data`

---

## Account Delegation (EIP-7702)

**Trigger**: ETH sent to an arbitrary/user address (`.call{value:}`, `transfer`, `send`), `tx.origin`, `code.length`/`extcodesize` on `msg.sender` or a user-supplied address, "recipient is an EOA" assumptions, batched/atomic user actions, approvals granted TO a user address

Since EIP-7702, an EOA can install a delegation designator (`0xef0100 ‖ impl`) and run that implementation's code in its own storage context.

1. **EOA recipients can re-enter**: sending ETH or calling back a user address that was assumed to be a "simple EOA" can now execute attacker code. Any CEI/reentrancy reasoning that relied on "the recipient is an EOA, so no callback" is invalid. Re-check refunds, payouts, sweep-to-user, and push-payment paths for reentrancy.
2. **Atomic multi-action from an "EOA"**: a delegated EOA can perform several operations atomically in one call. Invariants of the form "an EOA cannot do X and Y in the same transaction" (e.g. deposit-then-withdraw guards, per-tx one-action limits) no longer hold.
3. **Delegation is mutable**: an account's code can be set, changed, or removed between transactions. Approvals/allowances granted TO such an account persist across delegation changes — a benign-looking account today can behave adversarially after re-delegation.
4. **Authorization replay**: a 7702 authorization signed with `chainId == 0` is valid on any chain, and authorizations are nonce-bound to the authority. If the protocol reasons about who set an account's code, treat that as attacker-controlled and replayable across chains.
5. **`tx.origin` still not an EOA proof**: `tx.origin` can be a delegated account executing arbitrary logic; do not use `tx.origin == msg.sender` as a "no contract in the middle" gate.

**NOT a 7702 issue when**: the recipient path already assumes untrusted contract recipients (CEI correct + reentrancy guard); the EOA-only gate is a UX hint with no security dependency; value only moves to protocol-controlled trusted addresses.

---

## Time / Randomness

**Trigger**: `block.timestamp`, `now`, `block.number`, `blockhash`, `block.prevrandao`, `block.difficulty`, lotteries, raffles, random IDs, time locks, expiries, emission windows, vesting, auctions, epoch transitions

1. **Randomness source**: chain attributes are public before/at execution and may be biased by validators/builders. If funds, NFT rarity, lottery winners, or privileged selection depend on them, require VRF, commit/reveal with strong salt, or another unbiased source.
2. **Same-transaction predictability**: can an attacker compute the "random" value in a contract call immediately before submitting the winning action? If yes, treat the value as attacker-known.
3. **Timestamp tolerance**: if `block.timestamp` changes eligibility, price, fee, auction close, or liquidation outcome, quantify whether small timestamp drift or block-building choice changes who wins or how much value moves.
4. **`block.number` as time**: block intervals vary across chains and after upgrades. Check whether using block count for vesting, interest, deadlines, or cooldowns can unlock too early/late on the target deployment chain.
5. **Old blockhash**: `blockhash(n)` only works for recent blocks and returns zero outside the window. Check whether zero or a stale blockhash creates predictable outcomes or bypasses.
6. **Deadline boundary**: verify `<=` vs `<` matches the intended final valid second/block. Boundary mistakes around expiry can enable one extra execution or premature denial.

**NOT a time/randomness issue when**: time only gates low-value administrative scheduling with slack; randomness is not security-relevant; VRF or commit/reveal is correctly bound to sender, chain, contract, epoch, and a high-entropy salt.

---

## Signature / Hash

**Trigger**: `ecrecover`, `ECDSA.recover`, `abi.encodePacked` feeding into `keccak256`

1. Replay protection: does signed hash include nonce + `address(this)` + `block.chainid`? Missing any = replayable
2. `ecrecover` returns `address(0)` on invalid input. Is recovered address checked != address(0)?
3. Signature malleability: `(r, s)` has complement `(r, n-s)`. If dedup uses raw signature bytes (`mapping(bytes => bool)`) → bypass. Fix: dedup by hash/nonce, or use OZ ECDSA (enforces low-s)
4. `abi.encodePacked` with 2+ adjacent variable-length args (string, bytes, dynamic arrays) → hash collision. `abi.encodePacked("a","bc") == abi.encodePacked("ab","c")`. Fix: use `abi.encode`
5. Is nonce incremented BEFORE execution? If after → reentrancy-based replay possible

**NOT a signature issue when**: EIP-712 domain separator with nonce used; OZ ECDSA library used; only fixed-length args in encodePacked

---

## Price / Oracle

**Trigger**: `latestRoundData()`, `getReserves()`, `slot0()`, `observe()`, any price read from external source

1. Stale data: is `updatedAt` from Chainlink checked? Is there a max-age threshold?
2. `answer <= 0`: is this handled? Negative/zero prices should revert
3. L2 sequencer: is sequencer uptime feed checked? (Arbitrum, Optimism)
4. AMM spot price: `getReserves()` or `slot0()` is flash-loan manipulable. Need TWAP with sufficient window
5. Decimal mismatch: oracle decimals vs token decimals. USDC=6, Chainlink ETH/USD=8, WBTC=8
6. **Oracle update timing**: can an oracle/keeper update and a user operation execute in the same block or transaction? If a stale/old price is safe but a just-updated price is unsafe (or vice versa), check whether the protocol snapshots price, enforces heartbeat/deviation bounds, or gives users a delay/exit window.

---

## Transaction Ordering / MEV

**Trigger**: swaps, liquidity add/remove, auctions, mints with limited supply, first-come queues, liquidations, claims/rewards, commit/reveal, `minOut`/`maxIn`, `deadline`, functions whose result depends on current price/reserves/queue position, keeper/oracle updates followed by user execution

1. **Slippage bounds**: does the user supply `minAmountOut`, `maxAmountIn`, minimum shares, or equivalent? If output is computed from live reserves/oracles and no user bound exists, sandwich/front-run can extract value. Check that the bound is enforced against the actual received amount, not just a quoted amount.
2. **Deadline / expiry**: does the user operation expire (`deadline`, block number, epoch)? If a signed order or swap can be executed indefinitely, stale prices or changed market conditions can be exploited. Deadlines must be checked before state changes.
3. **Sandwich surface**: can an attacker move price before the victim and unwind after? Simulate: attacker trade -> victim execution at worse bound -> attacker backrun. If the victim's slippage is unbounded or protocol-set too wide, quantify extractable value.
4. **Displacement / copy-trade**: does the transaction reveal a secret, winning answer, permit, route, salt, or bid before it is protected by state? If copying the calldata lets another caller claim the same reward or position first, require commit/reveal, sender binding, or delayed/batched settlement.
5. **Commit/reveal binding**: commit hash must bind `msg.sender`, contract address, chain id, round/epoch, action parameters, and a high-entropy salt. Reveal must be in the correct phase, one-use, and unable to reveal in the same transaction/block if that defeats secrecy.
6. **Queue ordering**: for FIFO queues, auctions, withdrawals, redemptions, and liquidations, can a user cancel/reinsert, split orders, spam dust, or pay more gas to jump priority? Check whether ordering is deterministic and whether griefing can suppress other users.
7. **Privileged ordering**: can admin/keeper/oracle actions be ordered immediately before user execution to change fees, prices, caps, routes, or eligibility? If yes, check timelock, delay, snapshot, settle-before-change, and user exit protections.
8. **Block stuffing / suppression**: if safety depends on another transaction landing soon (oracle update, liquidation, reveal, keeper call), can delaying it for several blocks create profit or user loss?

**NOT an ordering issue when**: user-provided bounds are enforced on final output; batch auction or commit/reveal removes ordering advantage; oracle value is snapshotted before user commitment; operation is only admin-internal with no user-facing value impact.

---

## Value Flow (deposit / withdraw / mint / burn)

**Trigger**: functions that move value in or out of the protocol

1. **Symmetry**: does withdraw undo everything deposit does? Every field set, every counter incremented, every mapping entry — check the reverse operation
2. **Idempotency**: `deposit(100)` should produce same result as `deposit(50)` twice. Large differences indicate errors
3. **First depositor / inflation**: when `totalSupply == 0`, can attacker get 1:1 shares, donate to inflate price, then subsequent depositors get 0 shares from truncation? Check for: dead shares in constructor, virtual offset (OZ ERC-4626 pattern), `totalSupply == 0` special case
4. **Balance vs accounting**: does contract use `balanceOf(this)` as source of truth? Tokens/ETH can be force-sent to inflate it. Should use internal accounting variable
5. **Fee avoidance**: can fees be bypassed via zero-amount operations, self-transfers, or transaction structuring?
6. **src == dst**: what happens when sender and recipient are the same? In delegation systems, self-transfer may create phantom state changes
7. **Partial-claim timestamp advance**: when a claim/harvest function caps the claimed amount (via allowance, balance, or rate limit), check whether the timestamp/checkpoint for FUTURE claims advances to current time even when `claimed < owed`. If so, the unclaimed portion is permanently forfeited

---

## State & Data Structures

**Trigger**: struct operations, mapping reads/writes, array push/pop/delete, storage vs memory keywords, inheritance lists, overrides, shadowed names

1. **Memory vs storage**: when a struct is loaded into a `memory` variable, modifications are on the copy — they are NOT written back to storage unless explicitly assigned. The only visible difference is the `memory`/`storage` keyword. If you see `Type memory x = storageMapping[key]; x.field = newVal;` — the storage is unchanged. Flag if no write-back follows
2. **Duplicates in user-supplied lists**: when a function accepts an `address[]` or `uint256[]` from a caller and iterates it for balance queries, reward distribution, or voting — duplicates enable double-counting. Check: is uniqueness enforced? Is the list from a trusted source (admin) or untrusted (user)?
3. **Swap-and-pop deletion**: deleting from an array by swapping with the last element changes TWO items — the deleted one and the moved one. The moved item now has a different index. If any external system or mapping tracks items by index, those references are now stale. Check: are there mappings keyed by array index? Does any event emit the index?
4. **Mapping default confusion**: `mapping(key => value)` returns the zero value for unset keys. If `0` / `false` / `address(0)` is also a valid meaningful value, the contract cannot distinguish "never set" from "set to zero". Check: does the code use `value == 0` to mean "not initialized"? Could a legitimate value of 0 bypass that check?
5. **Uninitialized state as sentinel**: checking `value == 0` or `address == address(0)` to detect "uninitialized" is fragile — 0 may be a valid initialized value, or a counter may decrement back to 0 after exhaustion. If the contract treats `value == 0` as "no limit set," exhausting the limit may re-enable unlimited access
6. **Inheritance order**: in multiple inheritance, verify the actual linearization and overridden function chosen by Solidity. A base contract order change can alter access checks, hooks, storage initialization, or accounting side effects.
7. **State variable shadowing**: if child and parent contracts use the same variable name or semantically identical variables, verify all reads/writes hit the intended slot. Shadowing can split authority, balances, or config across two variables that developers assume are one.

**NOT a data structure issue when**: struct is explicitly declared as `storage` reference; array is only modified by admin with known-unique inputs; mapping default is handled with a separate `exists` flag

---

## Low-Level / Assembly / Storage Layout

**Trigger**: `assembly`, Yul blocks, `calldataload`, `calldatacopy`, manual ABI decoding, `shr`, `shl`, `and`, `or`, `sload`, `sstore`, `mload`, `mstore`, `returndatacopy`, bit shifts/masks, packed fields, `delegatecall`, proxy fallback dispatch, custom storage slots, `bytes4` selectors, `abi.encodeWithSelector`, `msg.sig`, `fallback`, `receive`, `create`, `create2`, `selfdestruct`, `PUSH0`, chain-specific deployment

1. **Assembly justification**: is low-level code necessary? If the same behavior can be safely expressed in Solidity and no gas/compatibility reason is documented, treat the assembly as high-risk and verify every opcode effect.
2. **Assembly ABI / calldata decoding**: when assembly reads calldata with `calldataload`/`calldatacopy`, manually decodes selectors/arguments, or applies shifts/masks to calldata-loaded words, build a calldata source layout table before judging safety:
   - For top-level ABI calldata, bytes `0..3` are the external selector. The argument head starts at byte `4`; each top-level head word is 32 bytes, so arg0 head is bytes `4..35`, arg1 head is bytes `36..67`, and so on.
   - For dynamic top-level arguments, the head word is an offset relative to the start of the argument block, not relative to byte `0`. The tail at `4 + offset` contains the dynamic encoding, typically a length word followed by data/elements; nested dynamic types add their own relative offsets.
   - Map each hard-coded offset to the intended Solidity parameter and type. For dynamic types, resolve the top-level offset first, then map any tail reads against the decoded tail layout. Verify word alignment, dynamic offsets, and address extraction against the ABI layout. For a direct ABI-encoded `address` argument, the 32-byte word is `12` zero bytes followed by the `20` address bytes; `shr(96, calldataload(offset))` is the normal extraction pattern when `offset` points to that address word.
   - Check every external entry point that can reach the assembly block. Internal calls and public wrapper calls do **not** create new calldata; `calldataload` still reads the original external calldata, not the callee's Solidity parameters.
   - If Solidity already decoded the parameter, compare the decoded value with the assembly-loaded value for every caller. Any caller where they differ can redirect value, bypass validation, or revert unexpectedly.
   - Do not report a direct-call issue merely because an address is extracted with `shr(96, calldataload(addressSlot))`; report only when the offset, caller calldata, dynamic layout, or decoded-vs-loaded value can differ.
3. **Memory safety**: when assembly writes memory, check free memory pointer `0x40`, scratch space, zero slot `0x60`, allocated length words, and bounds for `calldatacopy`/`returndatacopy`. Ensure returned dynamic data length cannot force unbounded memory expansion.
4. **Storage slot correctness**: for `sload`/`sstore` or custom slots, verify slot constants, namespace uniqueness, and no collision with compiler-assigned storage, proxy slots, diamond storage, or inherited variables.
5. **Upgradeable storage layout**: for proxy/UUPS/beacon/diamond systems, verify new variables are appended only, types/order of existing variables are unchanged, base contract storage changes do not shift child storage, storage gaps are preserved, and namespaced storage identifiers are unique.
6. **Bit packing**: when multiple values share one word, verify masks clear old bits before `or`, shifts use the correct offset and width, signed values are sign-extended deliberately, and values are range-checked before packing to prevent field bleed.
7. **Selector collision**: compute or reason about every externally routed `bytes4` selector in proxies, diamonds, routers, and fallback dispatch. Check for collisions between proxy admin functions and implementation functions, facet selectors, plugin modules, and manually specified selectors.
8. **Fallback/receive dispatch**: fallback code must reject unknown selectors unless intentionally forwarding. If it forwards, verify target address is trusted, return data is bounded, `msg.value` handling is correct, and admin calls cannot accidentally delegate into user logic.
9. **Delegatecall context**: `delegatecall` executes in the caller's storage context and preserves `msg.sender`/`msg.value`. Check user-controlled target/data, initializer locks, selfdestruct paths in implementation logic, and storage assumptions across caller/callee.
10. **Target-chain opcode compatibility**: if the deployment chain is not Ethereum mainnet, or compiler/opcode choices are chain-sensitive, verify `PUSH0`, `CREATE/CREATE2`, `.transfer()` gas behavior, precompile availability, and chain-specific system-contract semantics. A contract safe on one EVM chain can be undeployable or fund-locking on another.

**NOT a low-level issue when**: assembly is isolated, documented, has a high-level equivalent/test oracle, every hard-coded calldata/memory/storage offset is proven valid for all callers, memory and returndata are bounded, and storage slots/selectors are mechanically derived from audited constants.

---

## Transient Storage (EIP-1153)

**Trigger**: `tstore`, `tload`, Solidity `transient` storage variables, transient-based reentrancy locks, flash-accounting / unlock-callback settlement patterns

Transient storage persists for the WHOLE transaction — across every nested external call — and is wiped only at transaction end. It is address-scoped, and `delegatecall` shares the caller's transient namespace (same as regular storage).

1. **Lock not reset in the same call**: a reentrancy guard built on `tstore(slot, 1)` MUST `tstore(slot, 0)` before the protected function returns. If reset is skipped (or only done on the happy path), a later independent call in the SAME transaction sees the stale lock — either a permanent-within-tx DoS or, if the check is inverted, a bypass.
2. **Value leaks across external calls**: because transient survives nested calls, a value set before an external call is readable by a reentrant callee. Confirm whether that is the intended guard or an unintended information/authority leak into untrusted reentrant code.
3. **Assuming cross-transaction persistence**: transient does NOT survive to the next transaction. Any logic that stores a value transiently and expects to read it in a later tx is broken (reads zero).
4. **Flash accounting settlement**: in unlock/callback designs that net debits and credits in transient deltas and require settlement to zero before the unlock returns, trace EVERY path: a branch that credits without a matching debit, or returns from the callback with nonzero outstanding deltas unsettled, can drain the pool.
5. **delegatecall / proxy slot collision**: transient slots collide across a `delegatecall` just like storage slots. Verify transient slot constants are namespaced and cannot collide with a delegate target's transient usage.
6. **Guard stuck on revert-in-try/catch**: if the protected body can revert inside a `try/catch` without unwinding, confirm the transient lock is cleared; a stuck transient lock griefs every remaining call in the transaction.

**NOT a transient-storage issue when**: the lock is set and cleared within the same call frame via a modifier that wraps the whole body; transient is used purely as within-call scratch and never read after the protected section; deltas are provably settled to zero on all callback exit paths.

---

## Configuration Change

**Trigger**: `setRate`, `setFee`, `setHandler`, admin parameter updates

1. Does changing the parameter settle/finalize pending state first? (e.g., changing fee rate should settle accrued fees at old rate before applying new rate)
2. Is the change reversible? Can admin undo it? If irreversible, is that documented?
3. Can the new value break existing invariants? (e.g., setting fee to 100%, setting address to 0)
4. Does the change interact with other mechanisms? (e.g., changing oracle address while positions are open)

**NOT a config issue when**: change is behind a timelock or multisig; parameter has documented bounds enforced in the setter (e.g., `require(rate < MAX)`); contract is explicitly admin-trusted and finding only describes "admin can set X to Y" without a concrete attack path beyond trust assumption

---

## Governance / Admin Risk Matrix

**Trigger**: `onlyOwner`, `onlyRole`, `AccessControl`, `Ownable`, `TimelockController`, `Governor`, `upgradeTo`, `upgradeToAndCall`, `pause`, `unpause`, `setOracle`, `setFee`, `setTreasury`, `sweep`, `emergencyWithdraw`, keeper/operator/guardian functions

Build a matrix for every privileged role:

| Role | Powers | Assets/users affected | Delay/multisig? | User exit? | Severity ceiling |
|------|--------|----------------------|-----------------|------------|------------------|

1. **Upgrade admin**: can it change logic for contracts holding funds? Check UUPS `_authorizeUpgrade`, transparent proxy admin separation, beacon blast radius, implementation initialization lock, storage compatibility, and whether users can exit before upgrade execution.
2. **Timelock / governance executor**: verify proposer, executor, canceller, and admin roles are separated. Delay should cover the full user exit period. Check bypasses via emergency roles, direct proxy admin ownership, or `executeBatch` ordering.
3. **Pauser / guardian**: document exactly what pauses. Can users still withdraw/exit? Can pauser permanently freeze funds, selectively grief users, or unpause into unsafe state?
4. **Keeper / operator**: keepers should not choose arbitrary recipients, prices, routes, or amounts beyond bounded parameters. If liveness depends on keepers, check what happens when they are offline or maliciously delay.
5. **Oracle / risk admin**: changing price feeds, LTVs, liquidation thresholds, caps, or asset lists should settle/snapshot dependent state first and enforce bounds. Check whether a parameter change can instantly liquidate users or make withdrawals impossible.
6. **Treasury / sweeper**: sweep functions must not transfer user deposits, escrowed funds, reward pools, or tokens accidentally sent but later claimable. Check token allowlists and accounting exclusions.
7. **Role lifecycle**: role grant/revoke/transfer should be access-controlled, two-step where appropriate, emit events, and avoid orphaning critical roles. Check whether compromised keys can be revoked without using the compromised role.
8. **User exit path**: for each harmful but authorized action, ask whether users can detect it, have enough time to withdraw, and can still withdraw while paused or during upgrade/timelock delay.

**Severity guidance**: if harm requires a fully trusted role acting maliciously and users accepted that trust model, cap at Low or Design Advisory. If code claims a role is constrained (timelock, bounds, proofs, multisig) but an implementation bug bypasses the constraint, assess normally.

---

## Finding Validation

Before writing any finding, apply these checks:

**Autonomy test**: Can a random EOA execute this attack unilaterally? If it requires someone else to act first:
- Victim must sign/approve → severity ceiling: High
- Admin must configure something → severity ceiling: Low
- Key must be compromised → not a smart contract vulnerability; dismiss

**Trace the profit**: Whose funds move to the attacker, via which `transfer`? If you cannot write "attacker calls X, Y tokens transfer from victim/protocol to attacker" → the finding is incomplete

**Privilege laundering**: Does the attack path appear unprivileged but actually require a prior privileged action? Trace `msg.sender` through every modifier in the chain

**Prerequisite chain compounding**: when an attack requires a sequence of independent preconditions (each held by a different party), evaluate the chain together. An attack requiring (a) a specific token listed AND (b) a user interaction AND (c) dust left in the contract is not the same severity as one requiring only (a). Assign the tier of the hardest prerequisite

**Full execution test**: From step 1 to final step — does every intermediate call succeed? Does state from step N survive to step N+1? Does the attacker end with more funds than they started?
