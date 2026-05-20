# Client Attack Patterns 5-8

Pattern families extracted from historical blockchain client vulnerabilities across 20+ ecosystems. Mechanism descriptions are preserved for pattern matching.

---

## PAT-05. Vote/Signature Deduplication Failures

**Broken invariant**
Quorum signals must count unique, authorized participants exactly once.

**Attacker input surface**
Vote extensions, observer votes, DAO tallies, validator signatures, and replayable event attestations.

**Trigger condition**
The code increments weight or advances state without proving uniqueness, quorum membership, and message binding.

**State-transition path**
Vote or attestation accepted → uniqueness/quorum check absent or incomplete → state transition executes as if quorum was met.

**Impact envelope**
Effects include halts, forged approvals, incorrect nonces, and double-spend style safety failures.

**False-positive signal:** every accepted vote is keyed by signer, domain, height, and nonce before state changes.

**Recurring disguises / variants**
- Duplicate vote counted twice
- Observer can advance nonce without quorum
- DAO vote stake can be doubled by identity/accounting mismatch
- Voting index inconsistencies allowing the same approval to occupy multiple future slots

**Audit questions**
- What exact key prevents the same voter or observation from being counted twice?
- Is quorum checked before or after state mutation?
- Can replay across height, chain, or message type reuse the same authorization?

**Attack surfaces to investigate**

- **Duplicate vote aggregation:** Vote or attestation pipelines where the deduplication key is incomplete (missing height, domain, or round), allowing the same logical vote to influence aggregation weight more than once.
- **Observer nonce advancement without quorum:** Observer or relayer logic that advances nonce state or marks events as "confirmed" upon receiving a single message, without verifying that a true quorum of distinct signers was reached.
- **Identity/accounting mismatch in governance:** DAO or governance voting where stake weight is derived from a different source than identity deduplication, allowing the same economic weight to be counted through multiple identities.
- **Voting index slot reuse:** Voting data structures where index assignments allow the same logical approval to occupy multiple future slots, enabling double-spend style state evolution across epochs or rounds.

---

## PAT-06. Non-Deterministic Execution Causing Chain Split

**Broken invariant**
Every honest node must derive the same result from the same block inputs and prior state.

**Attacker input surface**
Map iteration, platform-dependent type widths, parser differences, frame decoders, and external dependency sizing rules.

**Trigger condition**
Consensus code depends on iteration order, host architecture, or implementation-specific parsing details.

**State-transition path**
Shared input → implementation- or platform-dependent evaluation → node-specific result → split state or rejected blocks.

**Impact envelope**
Nodes diverge on canonical state, reject each other's blocks, or deadlock migration and replay tooling.

**False-positive signal:** ordering, sizing, and parsing are explicitly canonicalized before use in consensus logic.

**Recurring disguises / variants**
- Map iteration in leader or vote selection
- 32-bit versus 64-bit `usize` or `size_t` behavior
- Decoder disagreement between implementations
- L1 finality assumptions silently embedded in L2 reorg handling

**Audit questions**
- Does consensus logic depend on map order, host word size, or unspecified parser behavior?
- Can two implementations accept the same bytes but decode different frames or limits?
- Are all ordering decisions explicitly sorted and all widths explicitly bounded?

**Attack surfaces to investigate**

- **Unordered map iteration in consensus decisions:** Leader election, tie-breaking, or winner selection logic that iterates over hash maps or sets whose order varies by runtime, causing different nodes to make different but locally valid choices.
- **Architecture-dependent type width in opcodes:** VM instruction implementations or consensus arithmetic that uses platform-dependent types (`int`, `size_t`, `usize`), producing different results on 32-bit vs 64-bit validators.
- **Frame/message decoder disagreement:** Multiple node implementations or versions that decode the same wire bytes into different frames or apply different validity limits, enabling a malicious actor to craft messages that split the network.
- **Implicit L1 finality assumptions in L2 state sync:** Cross-layer state synchronization that silently assumes L1 finality properties (e.g., "blocks older than N are final") without handling upstream reorgs that violate those assumptions.

---

## PAT-07. RPC/API Endpoint Crash via Crafted Input

**Broken invariant**
Public API input must never reach an `unreachable`, nil dereference, or unbounded allocator.

**Attacker input surface**
JSON-RPC, GraphQL, REST, debug endpoints, and import or parser paths exposed to unauthenticated or lightly authenticated callers.

**Trigger condition**
A crafted request exercises an unchecked optional field, impossible-state assertion, or memory-heavy execution path.

**State-transition path**
Remote request → decoder / planner → assertion, nil dereference, or OOM path → node process crash or stall.

**Impact envelope**
The usual result is node-local DoS; if the endpoint is part of migration or consensus tooling, the blast radius can grow to chain halt.

**False-positive signal:** the endpoint enforces bounded resources and treats every parse branch as attacker-controlled.

**Recurring disguises / variants**
- Optional field dereferenced as mandatory
- `unreachable!()` in pagination or graph queries
- Import validation path allowing malformed metadata to reach a panic
- Gas accounting driving an allocator into OOM territory via unusual feature combinations

**Audit questions**
- Which handlers still contain `panic`, `assert`, `unwrap`, or nil dereferences?
- Can an API caller force unusually expensive simulation or parsing behavior?
- Do optional parameters change code paths without complete validation?

**Attack surfaces to investigate**

- **Import/module validation gaps:** RPC or admin endpoints that accept deployment artifacts (WASM modules, bytecode, plugin packages) with insufficient validation, allowing references to non-existent modules or malformed metadata to reach a panic in the execution layer.
- **Feature-combination OOM in simulation:** Simulation or dry-run endpoints where combining multiple features (gas model variants, EIP toggles, precompile sets) creates execution contexts that production blocks would never produce, driving the allocator into OOM territory.
- **"Impossible" branch in query handlers:** Query, pagination, or graph-traversal API paths containing `unreachable!()`, `assert`, or nil dereferences guarded by assumptions about valid state — attackers who can craft the "impossible" parameter combination via the public API can trigger these directly.

---

## PAT-08. Fee / Gas Calculation Errors

**Broken invariant**
Charged fees, refunded fees, and priority ordering must match the actual resource consumption and payer identity.

**Attacker input surface**
Post-handlers, fee sponsorship mechanisms, refund code, base-fee updates, tip accounting, and denomination conversion layers.

**Trigger condition**
The fee pipeline snapshots gas too early, pays the wrong actor, or converts pricing through the wrong denomination or multiplier.

**State-transition path**
Transaction executes → fee snapshot / refund / base-fee update uses wrong context → charges diverge from actual work or payer.

**Impact envelope**
Attackers can underpay, over-refund, inflate priority, or make the fee market misprice subsequent blocks.

**False-positive signal:** the fee engine recomputes against final gas usage and binds all payments to the true spender.

**Recurring disguises / variants**
- Refund sent to fee originator instead of fee sponsor
- Priority boosted by refundable tip
- Base-fee update fed an early gas snapshot
- Same early snapshot mistake infecting block-level policy rather than just refunds

**Audit questions**
- When is gas snapshotted relative to all post-execution work?
- Which account is debited and which account is refunded in fee-sponsorship flows?
- Are denomination conversion and multiplier lookups bound to the actual fee token?

**Attack surfaces to investigate**

- **Fee originator vs fee sponsor confusion:** Fee-sponsorship or fee-grant flows where the refund, receipt, or accounting is directed to the transaction originator instead of the entity that actually funded gas, creating a mis-accounting surface in every sponsored transaction.
- **Gas-limit inflation for fee market manipulation:** Transactions submitted with a gas limit near the block maximum that consume only a small fraction, then manipulate the fee market because the refund or base-fee calculation uses the declared limit rather than actual consumption.
- **Early gas snapshot before post-processing:** Fee pipelines that snapshot gas usage before all post-execution hooks (token transfers, event emission, state cleanup) complete, leaving trailing attacker-influenced operations unaccounted in the fee calculation.
- **Block-level policy poisoning via stale utilization:** Base-fee or congestion pricing algorithms that use the same stale gas snapshot, understating block utilization and mispricing fees for all subsequent users even if no single refund looks anomalous.
