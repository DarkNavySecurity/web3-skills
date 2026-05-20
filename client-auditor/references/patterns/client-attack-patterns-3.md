# Client Attack Patterns 9-12

Pattern families extracted from historical blockchain client vulnerabilities across 20+ ecosystems. Mechanism descriptions are preserved for pattern matching.

---

## PAT-09. P2P / Network Layer Resource Exhaustion

**Broken invariant**
Network ingress must stay cheaper for defenders to reject than for attackers to send.

**Attacker input surface**
P2P gossip, mempool admission, batcher/sequencer buffers, bundle submission, and validator cache management.

**Trigger condition**
An attacker can supply oversized, frequent, or structurally pathological traffic that consumes more memory, CPU, or queue capacity than the protocol charges or limits.

**State-transition path**
Traffic ingress → decode / buffer / rebroadcast / cache → backlog, OOM, or permanent starvation of honest work.

**Impact envelope**
Nodes crash, sequencers stall, validators fall behind, or block production pauses under pressure.

**False-positive signal:** every queue has a hard bound and overload sheds attacker work before honest work.

**Recurring disguises / variants**
- Snappy or frame bombs that fit pre-checks but expand massively
- Large bundles or blocks repeatedly reforwarded
- Hot path caches that grow with fork or backlog pressure
- Unsolicited reply messages pushing data into unbounded caches
- Flat-rate charging for variable-cost operations
- Sustained attacker-controlled backlog growth with insufficient buffer discipline

**Audit questions**
- What is the hardest bound on queue length, decoded size, and retained state per peer?
- Does overload shed attacker work first or honest work first?
- Can one poisoned item block subsequent traffic from being processed?
- Is there a correlation mechanism between outbound requests and accepted replies?
- What is the cost accounting for this message type vs. its actual resource consumption?

**Attack surfaces to investigate**

- **Sustained backlog growth outpacing recovery:** Message or transaction queues where the attacker's injection rate exceeds the node's drain rate, causing the backlog to grow monotonically — each malicious burst leaves the node further behind, with no convergence.
- **State sync size/version mismatch:** State synchronization paths where a message size error or optional protocol upgrade creates a version conflict between peers, halting sync or crashing nodes that receive unexpected payload sizes.
- **Fork-pressure cache unbounding:** Caches (JIT compilation, block candidates, execution results) that grow with fork depth or reorg frequency — an attacker who triggers frequent short forks can accumulate unbounded cache entries until OOM.
- **Per-peer state accumulation without eviction:** Any per-peer or per-connection data structure (pending requests, partial downloads, reassembly buffers) that grows with attacker traffic and lacks hard bounds or eviction, enabling memory exhaustion through sustained connections.

---

## PAT-10. Cross-Layer / Bridge Message Integrity Failures

**Broken invariant**
Cross-domain messages must reflect what actually executed, on the correct domain, exactly once.

**Attacker input surface**
Bridge events, message passers, witness migration tooling, relayer envelopes, and state sync between L1 and L2.

**Trigger condition**
The system treats a message envelope, log, or witness as authoritative without binding it to successful execution, correct domain, or exact parser expectations.

**State-transition path**
Cross-domain action → message/log/witness emitted or parsed incorrectly → relay or migration accepts wrong artifact → remote side acts on false history.

**Impact envelope**
The result is blocked queues, halted migrations, false withdrawals, or incorrect cross-chain state.

**False-positive signal:** messages are committed only after success, include full domain binding, and are parsed by a single canonical implementation.

**Recurring disguises / variants**
- Reverted transactions still emitting bridge-relevant logs
- Migration witness formats disagreeing across producers and consumers
- L1 reorg state sync accepting stale assumptions
- Queue poisoning blocking all legitimate items behind a fabricated event

**Audit questions**
- What proves that a cross-layer message came from successful execution on the intended domain?
- Can two parsers or versions decode the same witness differently?
- What prevents the same event or queue slot from blocking all subsequent progress?

**Attack surfaces to investigate**

- **Reverted-transaction log emission:** Bridge or cross-domain paths that emit events or messages even when the underlying transaction reverts, allowing a relayer to treat failed local execution as authoritative remote intent.
- **Error-type conflation in bridge control flow:** Bridge message handlers that treat distinct error types as equivalent (e.g., "not found" vs "forbidden"), changing control flow and allowing an attacker to redirect or bypass cross-domain processing without a cryptographic break.
- **Migration witness format disagreement:** One-shot migration or upgrade tooling where the witness producer and consumer use different format versions or schema expectations — a single malformed artifact blocks the entire migration pipeline.
- **Queue poisoning via fabricated pending events:** Cross-layer message queues where a fabricated or malformed event can enter a "pending" state that blocks all subsequent legitimate items, causing indefinite liveness failure without stealing funds.

---

## PAT-11. Unbounded Computation in Block Finalization / Block Processing

**Broken invariant**
Per-block work must stay bounded by explicit protocol limits, not attacker-controlled queue length or output size.

**Attacker input surface**
Block-finalization queues, deferred stake removals, WASM output aggregation, large redeem loops, and replay-prone durable nonce logic.

**Trigger condition**
The attacker can enqueue arbitrary work or force replay of expensive processing that is paid once but consumed many times.

**State-transition path**
User actions enqueue or amplify work → block-critical loop drains unbounded set → block exceeds resource budget or replays work incorrectly.

**Impact envelope**
The chain stalls, validators fall over, or critical queues remain permanently behind.

**False-positive signal:** chunking, pagination, per-block quotas, and priced output caps are enforced.

**Recurring disguises / variants**
- No minimum stake amount before queueing removal
- Unlimited stdout/stderr or result payloads from sandboxed execution
- State transition reprocessed because replay markers are incomplete
- Pay-once-execute-many through deferred queue amplification

**Audit questions**
- What caps the number of items or bytes processed in one block?
- Can an attacker pay once to enqueue many future execution costs?
- Does the block processor make progress if one item is pathological?

**Attack surfaces to investigate**

- **No minimum size before deferred queue entry:** Operations (stake removals, undelegations, redemptions) with no minimum amount, allowing an attacker to queue many dust-sized items cheaply and externalize the aggregated processing cost to block finalization.
- **Unbounded output from sandboxed execution:** Sandboxed programs (WASM, smart contracts, user-supplied scripts) whose stdout, stderr, return data, or event logs have no size cap — a malicious program generating heavy output causes OOM in the host.
- **Queue amplification via cheap accumulation:** Any path where the attacker pays a small per-item cost to enqueue work that is processed in bulk later — the exploitability threshold is whether the attacker can accumulate enough items before the expensive batch phase triggers.
- **Incomplete replay markers causing re-execution:** Durable nonce or transaction-replay logic where the "already processed" marker is set too late or not at all on error paths, allowing a failed transaction to be processed again on retry or replay.

---

## PAT-12. ZK Circuit Constraint Insufficiency

**Broken invariant**
Every semantic rule of the virtual machine must be constrained, not merely implied by a witness-construction convention.

**Attacker input surface**
Arithmetic gadgets, queue sorters, memory reads, code unpackers, and proof-system edge cases.

**Trigger condition**
The prover can choose witness values that satisfy the implemented constraints while violating the intended VM semantics.

**State-transition path**
Bad witness chosen → incomplete constraint set still verifies → invalid state transition accepted as proven.

**Impact envelope**
The blast radius is silent state corruption or invalid L2 execution that can be finalized as valid.

**False-positive signal:** every exceptional path, range bound, and queue invariant is explicitly constrained.

**Recurring disguises / variants**
- Remainder not constrained below divisor
- Skipped branch not constrained in the zero or out-of-bounds case
- Queue ordering or version binding only partially enforced
- Zero-divisor cases where the exceptional path is not isolated correctly

**Audit questions**
- What witness freedom remains if the happy-path arithmetic relation is satisfied?
- Are zero, overflow, and out-of-bounds cases constrained independently?
- Can reverted, skipped, or filtered items still leak into committed outputs?

**Attack surfaces to investigate**

- **Unconstrained arithmetic gadgets:** Individual arithmetic operations (multiplication, division, modular reduction) in the circuit where the constraint system does not fully determine the output — a malicious prover who controls the witness can choose values that satisfy the constraints but violate the intended VM semantics.
- **Under-constrained remainder in division:** Division gadgets where the remainder is not constrained to be less than the divisor, leaving the prover with extra witness freedom after satisfying the main relation — the circuit "looks right" but does not uniquely determine the result.
- **Ordering constraints on log/event queues:** Queue or log sorting circuits where reverted, filtered, or out-of-order items can still be arranged into an apparently valid sequence — if ordering is not explicitly constrained, false history becomes provable.
- **Zero-divisor and exceptional-path isolation:** Circuits handling division-by-zero, out-of-bounds access, or overflow cases where the exceptional path is not correctly isolated — the prover can force the circuit into a semantically wrong state transition by choosing witness values that hit the unconstrained exceptional case.
