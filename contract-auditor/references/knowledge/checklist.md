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

## Access Control

**Trigger**: `external`/`public` state-changing function, `initialize()`, `init()`, modifier chain

1. Does this state-changing function have access control? If no modifier AND no inline `require(msg.sender == ...)` → flag
2. `initialize()` / `init()`: has `initializer` modifier (OZ)? Or custom once-guard? Can be front-run if deploy and init are separate transactions?
3. `_disableInitializers()` in implementation constructor? Without this, anyone can init the implementation directly
4. Role management functions (`grantRole`, `addAdmin`): are they themselves access-controlled?
5. `delegatecall` target: is it user-controlled? If yes → attacker overwrites caller storage

6. **Compliance bypass via auth-transfer**: privileged transfer functions (`authTransfer`, `forceTransfer`) that bypass compliance checks — trace all caller paths upward to external entry points. Can any user-facing function reach the privileged path indirectly? Does the calling contract enforce the compliance checks the bypassed role assumes?

**NOT access control issue when**: function is intentionally permissionless (deposit, claim); access enforced in internal function called by all paths; atomic deploy+init via proxy constructor `_data`

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
4. AMM spot price: `getReserves()` or `slot0()` is flash-loan manipulable. Need TWAP with sufficient window (>= 30 min)
5. Decimal mismatch: oracle decimals vs token decimals. USDC=6, Chainlink ETH/USD=8, WBTC=8

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

**Trigger**: struct operations, mapping reads/writes, array push/pop/delete, storage vs memory keywords

1. **Memory vs storage**: when a struct is loaded into a `memory` variable, modifications are on the copy — they are NOT written back to storage unless explicitly assigned. The only visible difference is the `memory`/`storage` keyword. If you see `Type memory x = storageMapping[key]; x.field = newVal;` — the storage is unchanged. Flag if no write-back follows
2. **Duplicates in user-supplied lists**: when a function accepts an `address[]` or `uint256[]` from a caller and iterates it for balance queries, reward distribution, or voting — duplicates enable double-counting. Check: is uniqueness enforced? Is the list from a trusted source (admin) or untrusted (user)?
3. **Swap-and-pop deletion**: deleting from an array by swapping with the last element changes TWO items — the deleted one and the moved one. The moved item now has a different index. If any external system or mapping tracks items by index, those references are now stale. Check: are there mappings keyed by array index? Does any event emit the index?
4. **Mapping default confusion**: `mapping(key => value)` returns the zero value for unset keys. If `0` / `false` / `address(0)` is also a valid meaningful value, the contract cannot distinguish "never set" from "set to zero". Check: does the code use `value == 0` to mean "not initialized"? Could a legitimate value of 0 bypass that check?
5. **Uninitialized state as sentinel**: checking `value == 0` or `address == address(0)` to detect "uninitialized" is fragile — 0 may be a valid initialized value, or a counter may decrement back to 0 after exhaustion. If the contract treats `value == 0` as "no limit set," exhausting the limit may re-enable unlimited access

**NOT a data structure issue when**: struct is explicitly declared as `storage` reference; array is only modified by admin with known-unique inputs; mapping default is handled with a separate `exists` flag

---

## Configuration Change

**Trigger**: `setRate`, `setFee`, `setHandler`, admin parameter updates

1. Does changing the parameter settle/finalize pending state first? (e.g., changing fee rate should settle accrued fees at old rate before applying new rate)
2. Is the change reversible? Can admin undo it? If irreversible, is that documented?
3. Can the new value break existing invariants? (e.g., setting fee to 100%, setting address to 0)
4. Does the change interact with other mechanisms? (e.g., changing oracle address while positions are open)

**NOT a config issue when**: change is behind a timelock or multisig; parameter has documented bounds enforced in the setter (e.g., `require(rate < MAX)`); contract is explicitly admin-trusted and finding only describes "admin can set X to Y" without a concrete attack path beyond trust assumption

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
