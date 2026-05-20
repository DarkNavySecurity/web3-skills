# Client Attack Patterns 1-4

Pattern families extracted from historical blockchain client vulnerabilities across 20+ ecosystems. Mechanism descriptions are preserved for pattern matching.

---

## PAT-01. Negative / Illegal Input Amount Triggers Unrecoverable Panic

**Broken invariant**
Externally influenced values must be normalized before they reach panic-only constructors or fatal framework return paths.

**Attacker input surface**
User messages, queued deferred-processing work items, validator votes, and framework callbacks that forward untrusted numeric or enum-like values.

**Trigger condition**
A malformed value survives admission checks and hits a path that treats invalid input as a programmer error rather than a recoverable user error.

**State-transition path**
External input → decode or queue → consensus-path replay → panic/assert/fatal error return → block or process abort.

**Impact envelope**
Consensus-path variants halt the chain; node-path variants crash the local process until the triggering item is filtered or state is repaired.

**False-positive signal:** the value is clamped or converted to a normal error before the fatal sink is reached.

**Recurring disguises / variants**
- Negative balances or stake removals
- Illegal gas or size values that violate framework assumptions
- Framework-level handlers returning a fatal error when they only meant to reject a vote
- Deferred processing paths re-consuming user data without re-validating

**Audit questions**
- Which constructors, helper APIs, or framework return combinations can panic on invalid values?
- Can deferred processing paths re-consume user data without re-validating it at the final sink?
- Does the code confuse soft rejection with fatal execution failure?

**Attack surfaces to investigate**

- **Deferred re-validation gap:** User-submitted values (negative amounts, zero denominators, out-of-range enums) that pass initial admission but reach a panic-prone constructor in a deferred block-finalization or consensus-replay path without being re-validated.
- **Framework error contract mismatch:** Code paths where returning a certain error status (e.g., non-nil error with rejection) is treated as a fatal abort by the framework rather than a soft rejection — no forged signature needed, just the wrong return shape.
- **State-shaping into illegal conditions:** Attacker manipulates on-chain state (e.g., balances, stakes, governance parameters) so that block-finalization logic encounters a value the fatal-path constructor cannot handle, escalating a localized state anomaly into a chain halt.

---

## PAT-02. Error Handling Defect in Batch Processing Loops

**Broken invariant**
One malformed item in a batch must not poison processing of all remaining valid items.

**Attacker input surface**
Loops over validators, votes, queued requests, or accounting entries in block finalization, proposal processing, and governance workflows.

**Trigger condition**
A single item returns an error and loop control, cleanup, or state updates are handled asymmetrically.

**State-transition path**
Batch iteration → one element faults → break / partial update / swallowed error → later items skipped or state diverges.

**Impact envelope**
The result ranges from chain halt to silent selection bias, wrong vote tallies, or persistent accounting drift.

**False-positive signal:** the loop is intentionally all-or-nothing and full rollback is explicit and deterministic.

**Recurring disguises / variants**
- `break` where `continue` is required
- Only some state variables update on an error path
- Errors are logged and ignored without restoring invariants
- Winning candidate selected based on partial iteration

**Audit questions**
- Does a single invalid item stop, skip, or bias the rest of the batch?
- Are paired state updates preserved across success and error branches?
- What happens if the first, middle, or last batch element fails?

**Attack surfaces to investigate**

- **Early-exit loop control:** Batch loops over validators, votes, or queued items where a single malformed element triggers `break` instead of `continue`, suppressing processing of all subsequent valid items.
- **Partial state update in comparisons:** Loops that update a "winning" candidate (block, proposal, leader) without also updating the comparison baseline, so iteration order determines the outcome and an attacker who controls ordering controls selection.
- **Unbounded deferred batch size:** Paths where an attacker cheaply queues many small items (micro-stakes, micro-delegations, dust transactions) that are all processed in a single block-finalization batch with no per-block cap, causing liveness failure.

---

## PAT-03. EVM Compatibility Layer Impedance Mismatch

**Broken invariant**
The compatibility layer must preserve the semantic guarantees of the execution environment it claims to emulate.

**Attacker input surface**
Precompiles, bridge adapters, balance handlers, type conversion boundaries, StateDB wrappers, and lifecycle edge cases.

**Trigger condition**
Values or behaviors legal in the native chain but impossible in the reference VM are admitted without a compensating guard.

**State-transition path**
Cross-layer call or EVM action → translation boundary → mismatched semantics → unauthorized effect, inconsistent state, or crash.

**Impact envelope**
Depending on the mismatch, the outcome is fund theft, invariant breakage, or a consensus/liveness failure.

**False-positive signal:** the boundary rejects impossible states early and mirrors reference-client edge behavior exactly.

**Recurring disguises / variants**
- u256 to narrower native balance truncation
- Delegatecall into precompiles that rely on caller identity
- Optimizations that skip writes when state appears unchanged
- StateDB implementations that lose state transitions

**Audit questions**
- Where do native types, permissions, or lifecycle rules differ from the emulated VM?
- Can a call context such as `delegatecall` or internal bridge messaging change authorization meaning?
- Are impossible reference-VM states representable in the host implementation?

**Attack surfaces to investigate**

- **Precompile log forgery via delegatecall:** Precompiles whose logs are trusted as deposit or bridge evidence — if reachable via `delegatecall`, the caller context is preserved, letting an attacker synthesize bridge-valid logs without the corresponding economic action.
- **Impossible-state bridging:** Internal call paths that admit value shapes (negative amounts, overflowed balances) forbidden by the reference VM but representable in the host, causing the host balance routine to misinterpret the value.
- **Dual-accounting drift:** Lifecycle operations (`SELFDESTRUCT`, contract migration, storage clearing) that update one balance view (host or EVM) but not the other, enabling value duplication when the two views diverge.
- **Type-width truncation at conversion boundaries:** Conversions from u256 to narrower native types where the attacker chooses values just above the native boundary, causing the system to accept a full-width amount but settle only the truncated low bits.

---

## PAT-04. Validator Set / Staking Hook State Inconsistency

**Broken invariant**
Validator-set invariants must hold across the full transition, not just before and after it.

**Attacker input surface**
Staking hooks, validator join/leave flows, penalty recovery logic, and any callback that observes or mutates validator membership in-flight.

**Trigger condition**
A hook or callback executes against an intermediate state where coupled validator-set fields have not been updated atomically.

**State-transition path**
Validator transition begins → hook or callback observes partial state → invariant check or downstream action consumes inconsistent membership.

**Impact envelope**
The chain can halt, choose the wrong validator set, or accept duplicate participation.

**False-positive signal:** transitions are atomic or hook visibility is restricted to committed state.

**Recurring disguises / variants**
- Max validator count temporarily exceeded
- Exiting validators still participating in vote processing
- Duplicate validator activity caused by operational failover

**Audit questions**
- Which hooks run while the validator set is only partially updated?
- Can another validator be added, removed, or have penalties reversed during the same transition?
- Do invariant checks run on intermediate or committed membership state?

**Attack surfaces to investigate**

- **Mid-transition hook execution:** Validator join/leave flows where hooks or callbacks observe intermediate state (e.g., active-set count temporarily exceeds maximum) before the atomic update completes, enabling invariant violations.
- **Faulty proposal divergence:** A validator issuing a malformed or conflicting proposal that causes a subset of block producers to fork, splitting the network between nodes that accepted and rejected the proposal.
- **High-availability failover duplication:** Validator operator infrastructure (hot-spare, active-active) where a malfunctioning failover node produces duplicate blocks or votes at the same slot height, creating equivocation conditions.
