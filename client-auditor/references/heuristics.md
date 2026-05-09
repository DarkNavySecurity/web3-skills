# Heuristic Strategies

Strategies for finding vulnerabilities that patterns alone won't catch. These are signals that warrant deeper investigation — places where bugs hide even when no specific pattern applies.

---

## Structural Suspicion

Code structure itself reveals risk. Look for:

- **State machines without explicit invariant enforcement** — code that handles state transitions without making the valid states and transitions explicit. Where does this state machine actually enforce its invariants? Can an attacker force a transition that skips validation or reset the machine to replay a transition?
- **Cross-subsystem caller assumptions** — a function that assumes its caller has validated input, but is called from a new context where validation is skipped. Grep for the function's callers — if any caller skips validation the function expects, that's a finding.
- **Asymmetric trust** — code that trusts local state but accepts peer-supplied values that override it. A function validates parameters when called from RPC but not when called from P2P — same logic, different trust assumptions.
- **Error path divergence** — the happy path is well-tested; the error/recovery path is not. Error handlers that attempt partial rollback, retry, or fallback often contain state corruption bugs.
- **Copy-paste with subtle differences** — two handlers that look almost identical but differ in one check or one field. The difference is either intentional (document why) or a bug.

---

## Complexity Signals

Complexity doesn't mean "vulnerable," but it correlates with unexamined assumptions:

- **Functions significantly longer or more branchy than their neighbors** — complexity without a good reason is often where bugs hide. Apply branch exhaustion with extra care.
- **Reimplemented standard functionality** — code that re-implements something the standard library already provides (custom parsers, custom encoders, custom hash maps). Reimplementations frequently have subtle off-by-one or boundary condition errors.
- **Multiple layers of indirection before security decisions** — permissions checks buried 4 calls deep, validation separated from the code that relies on it by several layers of abstraction.
- **Protocol negotiation and version handling** — code that switches behavior based on protocol version or feature flags. Each combination is a separate attack surface.
- **Recursive or re-entrant paths** — functions that can be re-entered before previous invocations complete. Even without explicit recursion, message handlers that dispatch new messages can create re-entrancy.
- **Type conversion chains** — data that passes through multiple serialization/deserialization steps. Each step can lose information, change semantics, or introduce inconsistency.

---

## Temporal Assumptions

Bugs that depend on timing or ordering:

- **Assumed message ordering** — handler assumes message A arrives before message B. What if B arrives first, or A never arrives? What if an attacker interleaves messages from multiple connections?
- **Time-of-check to time-of-use (TOCTOU)** — a condition is checked, then acted upon later. Between check and use, can an attacker (or another thread/async task) change the state?
- **Initialization dependencies** — code that relies on external setup having already happened. What if it hasn't? What if initialization is re-run while the system is already operating?
- **Timeout and expiry interactions** — what happens when a timeout fires during an in-progress operation? Does the timeout handler conflict with the operation handler?
- **Epoch and round transitions** — consensus code that assumes operations complete within a single epoch/round. What if the epoch advances mid-operation?
- **Cleanup that can be skipped** — early returns before cleanup, panic recovery that drops cleanup, error paths that skip resource release.

---

## Cross-Boundary Data Flow

Data that crosses trust boundaries deserves scrutiny at every crossing:

- **Serialization boundaries** — data entering or leaving the node (network, disk, RPC). Every field in a serialized message is attacker-controlled until validated. Deserialization libraries validate format, not meaning.
- **Subsystem boundaries** — data passed between internal components (e.g., P2P layer hands data to consensus layer). Each subsystem may assume the other validated the data. Check: who actually validates?
- **Privilege boundaries** — data from an unprivileged context used in a privileged operation. Even if the data was valid when received, has it been modified between receipt and use?
- **Aggregation of peer-supplied values** — vote weights, fee estimates, block hashes. The aggregation itself can be the vulnerability even if individual inputs are valid (e.g., overflow in summation, quorum miscounting).
- **Values validated at ingress but used later** — data validated on receipt, then passed through several functions. Could it be mutated in between? Could the validation become stale?

---

## Cross-Subsystem Interactions

These are uniquely valuable because no single-subsystem analysis can find them:

- **Functions that bridge two subsystems** — a P2P handler calling a shared serialization function, an RPC handler triggering consensus logic, a transaction processor accessing the networking layer.
- **Data structures shared across subsystem boundaries** — without clear ownership contracts. Who is responsible for invariant enforcement? Who cleans up?
- **Trust level mismatches** — code in a lower-trust subsystem (e.g., P2P) calling into a higher-trust subsystem (e.g., consensus) without re-validation at the boundary.

---

## Implicit Global State

Hidden shared state is where race conditions, resource exhaustion, and state corruption live:

- **Global maps and caches without bounds** — in-memory data structures that grow based on external input. Grep for global/static maps, then check: is there a size limit? Is there eviction? Can an attacker fill it?
- **Reference counting and shared ownership** — objects with multiple owners. Can one owner free/invalidate while another is using? Especially dangerous in C++ with `shared_ptr` across threads.
- **Metrics and counters** — counters that grow without bound, especially those used in allocation decisions or comparisons. An attacker who can increment a counter to overflow can invert a comparison.
- **Configuration state assumed immutable** — code that reads config once and assumes it doesn't change. If config can be updated at runtime (hot reload, admin RPC), cached config values may diverge from reality.
- **Connection and peer state** — per-peer state stored in global structures. If peer disconnection doesn't clean up all state, reconnection can interact with stale state from the previous session.

---

## Pattern Cross-Reference

Before assigning a `HEURISTIC` ID, check whether the bug maps to a known pattern family (P1-P20). If it does, use `{subsystem}-P[N]-[NN]` instead. `HEURISTIC` IDs are reserved for bug classes that genuinely don't fit any existing pattern.
