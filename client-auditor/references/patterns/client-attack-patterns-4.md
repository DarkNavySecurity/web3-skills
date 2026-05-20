# Client Attack Patterns 13-16

Pattern families extracted from historical blockchain client vulnerabilities across 20+ ecosystems. Mechanism descriptions are preserved for pattern matching.

---

## PAT-13. Resource Charging Order Violation (Pay-Before-Execute)

**Broken invariant**
Expensive work must not execute before the system proves that the caller has paid for it and host resources are reclaimed.

**Attacker input surface**
VM instructions, contract loading, host-VM FFI bridges, and native-language ABI ownership boundaries.

**Trigger condition**
The system performs memory clears, contract loads, or native allocations before gas charging or without matching frees.

**State-transition path**
Instruction or host call begins → expensive work / allocation occurs → billing or cleanup is skipped, late, or partial → attacker repeats cheaply.

**Impact envelope**
CPU, memory, or native resources are consumed asymmetrically, enabling DoS or long-lived leaks.

**False-positive signal:** charging and ownership transfer happen before the expensive operation begins.

**Recurring disguises / variants**
- Load contract before charging copy cost
- Allocate native strings or buffers without freeing them across FFI boundaries
- Clear memory or compute witness data before gas validation
- Repeated low-cost calls accumulating unreclaimed resources

**Audit questions**
- Which expensive operations begin before gas or fee charging succeeds?
- Do host-language ownership rules match the FFI allocation strategy?
- Can repeated low-cost calls accumulate unreclaimed resources?

**Attack surfaces to investigate**

- **Unprivileged FFI memory leak accumulation:** Host-VM bridge paths (WASM, native plugins, FFI calls) where each invocation allocates native memory that is never freed by the host-language runtime — repeated unprivileged calls accumulate unreclaimed allocations into network-level memory pressure.
- **Heavy work before gas charge:** VM instructions or host functions that perform expensive operations (memory clearing, data copying, hash computation) before checking whether the caller has sufficient gas — an attacker buys minimal gas and extracts disproportionate validator work.
- **Contract/module load before billing:** Code loading or compilation paths where the expensive contract load, decompression, or JIT compilation executes before the gas or fee check — repeated low-cost calls to non-existent or minimal contracts become a resource extraction tool.

---

## PAT-14. Transaction Replay / Frontrunning / Censorship

**Broken invariant**
A transaction or event must be bound to the right sender, chain, nonce, and context before it influences scarce resources or state.

**Attacker input surface**
Mempools, bridge ingress, observer queues, UTXO tracking, and cross-chain transaction admission logic.

**Trigger condition**
Identity, uniqueness, or chain binding is checked too late or not at all, so a copied payload consumes shared resources or mutates state.

**State-transition path**
Legitimate payload observed → adversary replays or front-runs → scarce slot or state transition consumed before true sender is recognized.

**Impact envelope**
The victim loses inclusion, resources are exhausted, or cross-chain queues remain blocked or inconsistent.

**False-positive signal:** the message is bound to chain ID, sender, nonce, and resource accounting before queuing.

**Recurring disguises / variants**
- Signature valid but sender field unchecked
- Rate limit applied before chain ID validation (enabling cross-chain replay to exhaust limits)
- Queue key does not include enough replay-resistant context
- UTXO reuse in stateless SDK transaction builders
- Queue poisoning via fabricated events that block all legitimate items

**Audit questions**
- What exact tuple makes a payload unique in this system?
- Are replay checks applied before scarce resources such as rate limits or queue slots are consumed?
- Can an attacker partially mutate a copied payload without invalidating the authorization?

**Attack surfaces to investigate**

- **Signature-valid but sender-unverified replay:** Transaction admission paths where payload signature verification passes but the sender/origin field is not independently verified — an attacker who observes a legitimate transaction can replay the same payload from a different sender to front-run or duplicate the action.
- **Stateless UTXO/input selection in client SDKs:** Client SDK transaction-building methods that select inputs (UTXOs, coins, nonces) without tracking in-flight transactions, causing the same input to be selected for multiple transactions within the same block.
- **Rate-limit exhaustion via cross-chain replay:** Rate limiting applied before chain ID or domain validation — attackers replay transactions from other chains to exhaust rate limits for legitimate users on the target chain.
- **Pending-state queue poisoning:** Message or transaction queues where a fabricated or malformed entry enters a "pending" state that blocks all subsequent legitimate items, causing indefinite processing stall without requiring value theft.

---

## PAT-15. Precision Loss in Financial Calculations

**Broken invariant**
Accounting precision must be sufficient to preserve conservation of value across rounding boundaries.

**Attacker input surface**
Reward distribution, weighted loss calculations, share accounting, and conversions between decimal and integer units.

**Trigger condition**
Intermediate precision is truncated or overflowed before the final conservation check, leaving residual value or invalid totals.

**State-transition path**
Value aggregation → intermediate truncation or overflow → final accounting mismatches actual reserves or intended reward split.

**Impact envelope**
Outcomes include locked funds, under-collateralized module accounts, or failed processing when arithmetic exceeds bounds.

**False-positive signal:** the system keeps high-precision intermediates and proves where residual dust is sent.

**Recurring disguises / variants**
- Trimmed decimal reward before checking available funds
- Large weighted value multiplication overflowing bounded integer types
- Integer truncation in share-to-asset conversions allowing rounding exploitation
- Accumulated rounding errors growing as O(N * epsilon) with repeated operations

**Audit questions**
- Where do decimal values become integers, and who absorbs the residual?
- Can attacker-chosen inputs maximize overflow or truncation before invariants run?
- Is value conservation proven on the exact representation used for settlement?

**Attack surfaces to investigate**

- **Iterative multiplication overflow in aggregation:** Aggregation functions (loss calculation, reward distribution, weight computation) that iteratively multiply attacker-influenced values across a collection — malicious data can push intermediate products past the maximum value of the bounded integer type, crashing the computation or wrapping to incorrect results.
- **Precision loss exceeding pool balance:** Reward distribution or fee refund paths where precision loss during truncation/rounding causes the computed payout to exceed the actual pool or module account balance, breaking accounting invariants and potentially locking funds.

---

## PAT-16. Module/Component Wiring Failures

**Broken invariant**
Declared features must be fully registered, initialized, and connected to the components that are supposed to use them.

**Attacker input surface**
Module/component registries, resolver initialization, CLI wiring, spec-to-implementation glue, and infrastructure configuration layers.

**Trigger condition**
A feature compiles or appears configured, but one registration, initialization, or routing step is missing or points to the wrong component.

**State-transition path**
Feature invoked → missing registration / initialization / binding → wrong component, no-op behavior, or spec drift.

**Impact envelope**
The result is often operator-facing failure, but if the missing wiring sits on consensus or fee paths it can escalate into liveness or economic issues.

**False-positive signal:** startup asserts full wiring and integration tests exercise the real runtime path.

**Recurring disguises / variants**
- Component not added to the module/component registry
- Resolver declared but never initialized
- Implementation silently diverges from published spec or reference behavior
- Token factory hooks accepting invalid address assumptions from configuration
- Version hash enforcement missing in integration-layer safety checks

**Audit questions**
- What runtime assertion proves this component is actually wired into the live system?
- Do startup tests exercise the real registration path rather than mocks?
- Is the implemented behavior still aligned with the published spec and operational assumptions?

**Attack surfaces to investigate**

- **Spec-implementation divergence:** Features where the published specification and the actual implementation disagree — integrators and auditors reason about the spec, so a mismatch causes one side to encode or verify the wrong rule, with the divergence potentially exploitable.
- **Configuration-controlled hook with invalid assumptions:** Factory, plugin, or hook registration paths that accept attacker-controlled or operator-controlled configuration (addresses, parameters, feature flags) without validating assumptions — ordinary user flows can then hit the misconfigured hook.
- **Source-present but unwired module:** Modules or components that exist in source code and compile successfully but are never fully registered or initialized in the live application — the vulnerability is in integration/wiring code that operators rarely inspect.
- **Missing version hash binding in code loading:** Code unpacking or loading paths that do not bind the loaded bytecode to the version hash promised by the deployment artifact — downstream layers reason about the wrong bytecode semantics, enabling logic bypass.
