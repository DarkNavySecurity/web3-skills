# Auditing Heuristics

General thinking patterns for finding vulnerabilities in smart contracts. These are not concrete vulnerability classes — they are lenses through which to examine code. Apply throughout all passes.

---

## General Heuristics

### 1. Code Asymmetries
In many projects, there should be symmetries between paired functions. Does `withdraw` undo everything `deposit` does? Does `delete` undo everything `add` does? Asymmetries in these function pairs — forgetting to unset a field or subtract from a value — often lead to exploitable state.

### 2. Idempotency / Splitting
For functions like `deposit`, the resulting state should be (almost) the same when called X times with value Y or once with value X*Y. Large differences indicate errors. This is also an excellent fuzzing target.

### 3. Amplifiable Rounding
Small rounding errors are unavoidable, but they become critical when amplifiable — by calling a function repeatedly at predetermined moments, or by operating at extreme value scales.

### 4. Boundary Conditions
Off-by-one errors are ubiquitous. For every comparison: is `<=` correct or should `<` be used? For every array access: should it be `length` or `length - 1`? For every loop: start at 0 or 1? What happens with `length - 1` on an empty array?

### 5. Duplicates in Lists
Some code implicitly assumes lists contain no duplicates without enforcing it. When addresses are user-supplied and used for balance queries, duplicates enable double-counting.

### 6. EIP/Standard Compliance
Standards define exact behavior for edge cases. Not reverting when required, using wrong rounding behavior, or returning incorrect values breaks composability and can create vulnerabilities.

### 7. src == dst
What happens when source and destination are the same address? In token contracts with delegation, a self-transfer may produce phantom voting power changes due to asymmetric before/after balance reconstruction.

### 8. Uninitialized State Detection
Checking `value == 0` (or `address(0)`, empty list) to detect "uninitialized" is fragile — these may be valid initialized values. This can allow re-triggering initialization logic.

### 9. Balance vs Deposits
Never conflate `balanceOf(address(this))` with internal accounting. Tokens and ETH can be force-sent to any contract, inflating the external balance without updating internal state.

### 10. Repeated Same-Parameter Calls
Functions that should only work once with given parameters (e.g., signatures, claims) — check for replay protection. Consider signature malleability as a replay vector.

### 11. Memory vs Storage
Contracts working on a `memory` copy of a struct may forget to write it back to `storage`. The only visible difference is a keyword — use tooling that highlights storage variables.

### 12. Unbounded Loops
When loop length is user-controllable and there's no way to specify start/end index, the array can grow until the function permanently exceeds the block gas limit.

### 13. List Deletion Side Effects
Deleting from a list by swapping with the last element changes TWO items — the deleted one and the moved one. The moved item now has a different index, which may be referenced elsewhere.

### 14. ETH/WETH Handling
If a contract wraps ETH to WETH when `msg.value > 0` and also accepts WETH directly, are these cases mutually exclusive? What if both are provided simultaneously?

### 15. Compliance Bypass via Auth-Transfer
Privileged transfer functions (`authTransfer`, `forceTransfer`) that bypass compliance checks: trace all caller paths upward. Can any user-facing function reach the privileged path indirectly? Does the calling contract enforce the compliance checks the role assumes?

---

## Prerequisite Feasibility Heuristics

These address a critical failure mode: correctly identifying a vulnerable code path while assuming preconditions an attacker cannot establish. A finding's severity is bounded by its hardest prerequisite.

### The Autonomy Test
**"Can a random EOA kick off this attack unilaterally, with no action required from anyone else?"** If yes, severity is uncapped. If the attack requires someone else to act first:
- Victim must approve/sign/call first → severity ceiling: High
- Admin must set a parameter or config → severity ceiling: Low (conditional future risk)
- A key must be compromised → not a smart contract vulnerability; dismiss

### Trace Where the Profit Comes From
**"Whose funds move to the attacker's address, and via which mechanism?"** Vague claims like "protocol state is corrupted" are not findings. The finding must close the loop from corrupted state to attacker balance increasing. If you cannot write "attacker calls X, Y tokens transfer from victim/protocol to attacker," the finding is incomplete.

### Privilege Laundering
Some attacks appear unprivileged but actually launder a privileged action through an indirect path. When tracing `msg.sender` through modifiers: **"Does this execution path become reachable only after someone with a role has taken a prior action?"** If yes, that role is a hidden prerequisite. Inversely, attacks that appear to require a role may not — the role check may be on a different code path.

### Prerequisite Chain Compounding
When an attack requires a sequence of independent preconditions (each held by a different party), evaluate the chain together. An attack requiring (a) a specific token listed AND (b) a user interaction AND (c) dust left in the contract is not the same severity as one requiring only (a). Assign the tier of the hardest prerequisite.

### The Full Execution Test
Do not stop tracing after confirming the vulnerability mechanism exists. Trace all the way to the final state change:
- Does every intermediate call succeed (no reverts, no failed checks)?
- Does the state set up in step N survive to be used in step N+1?
- Does the attacker actually end up with more funds than they started with?
