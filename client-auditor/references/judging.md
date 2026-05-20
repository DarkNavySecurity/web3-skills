# Finding Judgment Criteria

This document defines how findings from the pattern scan agents are evaluated and scored. The 3-lens evaluation is an analytical framework — use judgment when calibrating confidence. The severity override rules, in contrast, apply mechanically after analysis to prevent severity inflation; they are calibrated against historical audit experience and should not be deviated from without explicit reasoning.

---

## 3-Lens Evaluation Framework

Three lenses for calibrating confidence in a finding. They are anchors, not pass/fail gates. A finding weak on one lens is not automatically a false positive — report it with explicit caveats and reduced confidence, and let the reader decide. A finding weak on all three is usually noise.

### Lens 1: Concrete Execution Path

Strength signal: a concrete, traceable execution path from attacker-controlled input to the invariant break.

**Strong signals:**
- The path can be described as a sequence of function calls with specific file:line references
- Each step in the path is reachable from the previous step (no dead code, no disabled features)
- The attacker input that enters the path is specified (message type, RPC method, tx field, etc.)

**Weakness signals (note explicitly if reporting anyway):**
- Path requires calling internal-only functions not reachable from any entry point
- Path traverses code gated by compile-time flags that are off in production
- Path requires state that cannot be constructed through any external interface

### Lens 2: External Reachability

Strength signal: the entry point is reachable by an external actor (peer, RPC caller, transaction submitter), not only by internal code paths.

**Strong signals:**
- The entry point is a P2P message handler, RPC endpoint, transaction processor, or consensus hook
- The entry point can be reached without admin/operator credentials (or the finding explicitly notes the admin requirement)
- The network path from attacker to entry point is specified

**Weakness signals (note explicitly if reporting anyway):**
- Handler is only called from internal timers or maintenance routines
- Entry point requires localhost access AND default config binds to localhost
- Function is a test helper or debug-only path compiled out of release builds

### Lens 3: No Sufficient Existing Guard

Strength signal: no existing defense mechanism is sufficient to fully prevent the attack.

**Strong signals:**
- Each claimed mitigation has been checked against the actual code
- Mitigations are demonstrably insufficient (rate limit too high, size check on wrong field, etc.)
- The finding survives layered defense analysis (all mitigations considered in combination)

**Weakness signals (note explicitly if reporting anyway):**
- An existing check already validates the exact input that triggers the bug
- Rate limiting reduces the attack below the impact threshold
- The resource is bounded and the bound is enforced before the expensive operation

---

## Confidence Scoring

The inventory agent computes a confidence score (0-100) for every finding and persists it in the `confidence:` frontmatter field. The score is recomputed on every inventory rerun.

Start at 100 and apply deductions. Multiple deductions stack.

| Condition | Deduction | Rationale |
|-----------|-----------|-----------|
| Requires admin/operator privileges | -30 | Drastically narrows attacker population |
| Requires compromise of a hardened trusted-party key (guardian, validator, committee member, authorized signing key) | -40 | Prerequisite compromise constitutes a more severe independent incident; secondary effects do not meaningfully elevate risk above that baseline |
| Requires >33% Byzantine validators | -25 | Above standard BFT security assumption |
| Requires ≥ consensus quorum of compromised parties | -80 | Attacker already owns the protocol; secondary bugs are subsumed by the primary compromise |
| Requires non-default configuration | -20 | Most deployments unaffected |
| Feature gated behind activation flag, governance vote, or hard fork not yet deployed | -15 | Not currently exploitable in production |
| Impact is self-contained (attacker only harms themselves) | -15 | No externality to other users |
| Existing partial mitigation present | -10 | Reduces but does not eliminate risk |
| Requires sustained attack >1 hour (not applicable to instant-trigger bugs such as memory corruption or logic errors) | -10 | Increases detection probability |
| Input rejected by deserialization before reaching vulnerable code | -40 | Strong structural defense |
| No current exploit path exists — condition is unreachable in all present code paths | -50 | Latent/future risk only |

### Scoring examples

**Example A — High confidence:**
- Start: 100
- No admin required: 0
- Default configuration: 0
- Active feature: 0
- Partial mitigation (connection-level rate limit): -10
- Attack completes in minutes: 0
- **Final: 90 → HIGH**

**Example B — Low confidence:**
- Start: 100
- Requires admin privileges: -30
- Requires non-default config to expose: -20
- Self-contained impact: -15
- Existing input validation catches most cases: -10
- **Final: 25 → LOW**

---

## Severity Classification

Severity is assigned by inventory using the table below, gated by the persisted `confidence` field and the impact ceiling. Trust level (per `routing/trust-boundaries.md`) sharpens the impact assessment but does not replace it — `trust_level: 1` (Internet-reachable) raises the impact ceiling; `trust_level: 6-7` (operator / governance) lowers it via the override rules below.

| Severity | Criteria | Confidence Range |
|----------|----------|-----------------|
| **Critical** | Chain halt, chain split, or direct fund loss achievable by any peer/user (typically `trust_level: 1-2`) | ≥80 AND impact is chain-wide or financial |
| **High** | Node DoS from any peer, significant state corruption, or bypass of core security mechanism (typically `trust_level: 1-3`) | ≥70 |
| **Medium** | Requires non-default configuration, or causes degradation without full DoS, or has significant partial mitigations | 40-69 |
| **Low** | Theoretical with significant practical constraints, or requires unlikely preconditions | 20-39 |
| **Informational** | Design observation, defense-in-depth suggestion, or by-design behavior that warrants documentation | <20 |

### Severity override rules

These rules apply mechanically after the analytical lenses and confidence scoring. They are calibrated against historical audit experience and prevent severity inflation; do not deviate without an explicit, documented reason in the finding file.

1. **Never promote above the impact ceiling:** A finding that can only crash one node cannot be Critical, regardless of confidence.
2. **Downgrade for design intent:** If the behavior is explicitly documented as a design trade-off with formal analysis, cap at Informational.
3. **Upgrade for chain-wide impact:** If a Medium-confidence finding can cause chain halt or fund loss, it stays at Medium (not Low) — the impact justifies the attention even with uncertainty.
4. **Admin-only findings cap at Medium:** Findings requiring admin credentials are capped at Medium severity regardless of impact, unless the admin interface itself is the finding (e.g., admin credentials exposed).
5. **Trusted-party key compromise cap at Low (with system-wide exception):** Findings whose only exploit path requires compromise of a hardened trusted-party key (guardian key, validator key, committee member key, authorized signing key) are capped at **Low** by default. The key compromise itself is the high-severity incident; the secondary effect described in the finding does not independently elevate risk beyond that baseline. **Exception — upgrade to Medium** if a single compromised party can affect the entire system (e.g., corrupt shared global state, force a chain halt, block quorum for all honest participants, or produce an incorrect result visible to all consumers) rather than only degrading one local node. The test is whether the blast radius is system-wide or node-local: node-local → Low; system-wide with one compromised key → Medium.
6. **No current exploit path cap at Low / Informational:** Findings with no reachable exploit path in the current codebase (e.g., all existing code paths return an error before the vulnerable condition is reached, making the bug latent rather than active) are capped at **Low**. If the only risk is future code changes introducing the exploit path, cap at **Informational**.
7. **Self-recovering resource exhaustion cap at Medium:** Findings that (a) only increase resource consumption (CPU, memory, bandwidth, channel fill) without causing a crash, data loss, or correctness failure, AND (b) where the system returns to baseline automatically when the attack stops (e.g., via TTL expiry, channel backpressure, timeout, or GC), are capped at **Medium** regardless of confidence. "Self-recovering" means no operator intervention is required to restore normal operation after the attack ceases.
8. **Quorum-required exploit cap at Informational:** Findings whose exploit path requires compromising a number of parties equal to or greater than the system's consensus quorum threshold are capped at **Informational**. At quorum compromise, the attacker already has full control of the protocol — they can forge any message, update the validator/guardian set, and execute arbitrary governance actions. Any secondary bug exploitable only at quorum level does not independently elevate risk; it is subsumed by the catastrophic primary compromise. Report as a defense-in-depth observation only.

---

## Deduplication Rules

When multiple findings share the same root cause:

1. **Same function, same bug:** Merge into one finding. Use the highest severity.
2. **Same pattern, different entry points:** Keep separate but note the shared root cause. The fixing recommendation should address the root cause, not each instance.
3. **Cascading effects:** If Finding A enables Finding B, report both but note the dependency. If fixing A eliminates B, note that B is contingent.
