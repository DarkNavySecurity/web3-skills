# Finding Validation Protocol

Validation rigor scales with severity. High/Critical findings that claim real damage to users or the system must survive the full gauntlet. Low/Informational findings that flag genuine code issues are valid with lighter evidence — but they must still be **true valid findings**, not noise.

---

## Severity Tiers and Validation Requirements

| Severity | What it means | Validation required |
|----------|--------------|-------------------|
| Critical / High | Direct fund loss, permanent DoS, or privilege escalation affecting users | Full protocol: 3 Hard Gates + 6D Scoring + PoC Quantification |
| Medium | Conditional fund risk, griefing, state corruption with workaround, or DoS with recovery path | Gates 1-3 required, but profit can be indirect (blocked withdrawals, governance disruption, degraded functionality). 6D Scoring recommended but not mandatory. |
| Low | Valid code issue with potential future risk, edge-case misbehavior, or dependency on unlikely-but-possible preconditions | Gate 1 (concrete path) required — must identify the specific code and behavior. Gates 2-3 relaxed: the path may require unlikely preconditions (non-standard tokens, specific parameter configs, role actions). No profit requirement. |
| Informational | Code smell, deviation from best practice, design concern, or consequence of using a mechanism as designed | Must identify specific code location and explain what is wrong or surprising. No attack path required. Must be a **true valid observation** — not a linter warning, not a style preference, not a documentation nit. |

---

## Filter 1 — Three Hard Gates (Critical / High only)

**For Critical/High findings: fail ANY gate = discard.** For Medium: all three required but with relaxed profit expectations. For Low/Info: see tier table above.

### Gate 1 — Concrete Attack Path

Trace the complete path: `caller → function → state change → impact`. Every step must be specified with exact function names and parameters. "It could be exploited" without a concrete path = **discard**.

For Low severity: the path can end at "state corruption" or "unexpected behavior" without requiring value extraction. For Informational: identify the code location and the concern — no path required.

### Gate 2 — Attacker Reachability

The entry point is accessible and EVERY modifier/require on the path is satisfiable by the attacker. Verify each `onlyRole`, `whenNotPaused`, `nonReentrant`, and custom modifier. If any modifier blocks the attacker = **discard**.

For Low severity: the path may require unlikely but possible preconditions (admin action, non-standard token, specific market condition). State the prerequisite clearly.

**Payability sub-check** (mandatory for findings involving `msg.value`, ETH transfers, or payable calls): VERIFY the function is actually marked `payable` — read the function signature. For delegatecall chains: verify the ENTRY POINT is payable, not just the target. For multicall/batch patterns: verify the multicall function itself is payable. If the function is NOT payable, `msg.value` is always 0 = **discard**.

### Gate 3 — No Existing Safeguard

No `require`/`revert`/guard in the codebase already blocks this exact path. Search for protective checks you may have missed during analysis.

For Low severity: partial safeguards that reduce but don't eliminate the risk are acceptable — note the mitigation.

---

## Filter 2 — Six-Dimension Adversarial Scoring (Critical / High required, Medium recommended)

Score each dimension from -3 to +1:

| Dimension | -3 (strong protection) | 0 (neutral) | +1 (confirmed vulnerable) |
|-----------|----------------------|-------------|--------------------------|
| D1: Guards | require/assert/revert fully protects path | partial check exists | no guard on critical path |
| D2: Reentrancy | nonReentrant + CEI + no callbacks | CEI but external calls exist | state written after external call, no guard |
| D3: Access control | attacker cannot reach any function in chain | some functions gated, entry is public | full chain publicly accessible |
| D4: Design intent | documented as intentional behavior | ambiguous intent | clear divergence from documented intent |
| D5: Economic feasibility | attack costs more than profit | break-even or marginal | profitable after gas + capital costs |
| D6: Dry run | simulating with concrete values reverts | some steps unclear | every step succeeds with concrete values |

**Mechanical verdict from sum**:
- Sum <= -6 → **DISCARD** (protections are overwhelming)
- Sum -5 to -1 → **DOWNGRADE** one confidence tier
- Sum 0 to +2 → **EMIT** as-is
- Sum >= +3 → **ESCALATE** one confidence tier

**Skip this filter for Low/Informational findings.** They do not need adversarial scoring — their value is in flagging the code concern, not proving exploitability.

---

## Confidence Calibration

| Confidence | Evidence Required | Maps To |
|------------|-------------------|---------|
| 0.9+ | Fully-specified path — exact calls, values, profit amount. Could write PoC now. | `[100]` |
| 0.7–0.9 | Complete path but one precondition unverified | `[85]` |
| 0.5–0.7 | Plausible theory, multiple preconditions unverified | `[75]` |
| 0.3–0.5 | Valid code concern, edge case, or design issue without full exploit chain | `[60]` |
| < 0.3 | Speculative, no specific code identified | Do not report |

---

## Prerequisite Tier Table

Assign the tier of the HARDEST prerequisite in the chain. This caps the maximum severity for findings that claim High/Critical:

| Tier | Prerequisite | Severity Ceiling |
|------|-------------|-----------------|
| 0 | None — public, any EOA | Critical |
| 1 | Victim must sign/approve first | High |
| 2 | Specific market condition required | High |
| 3 | Non-standard token behavior assumed | Medium |
| 4 | Attacker needs protocol role | Low |
| 5 | Admin key compromise required | Low (report only if mechanism is concrete) |

Low/Informational findings are not subject to prerequisite tier capping — their value is in documenting the concern regardless of exploitability.

---

## What to Report at Each Severity

### Critical / High
- Direct fund theft or permanent lock
- Privilege escalation to drain protocol
- Unrecoverable state corruption affecting all users
- **Requires**: full 3 gates + 6D + PoC quantification + positive attacker profit

### Medium
- Conditional fund loss (requires specific token type, market condition, or timing)
- Griefing that costs the attacker but harms users (DoS, blocked operations)
- State corruption with admin recovery path
- Governance manipulation with concrete mechanism
- **Requires**: 3 gates (profit can be indirect — blocked functionality, degraded security)

### Low
- Unbounded array growth that doesn't currently iterate but could in future upgrades
- Missing input validation on edge cases (zero amount, self-transfer, empty array)
- Non-standard token handling gaps when token whitelist is admin-controlled
- Incorrect event emissions that could mislead off-chain systems
- CREATE2 frontrunning that blocks deployment but doesn't steal funds
- CEI violations where current token set has no callbacks but future tokens might
- **Requires**: specific code location + explanation of what could go wrong

### Informational
- Code asymmetries between paired operations (deposit/withdraw, add/remove)
- Dead code or commented-out logic suggesting incomplete changes
- Deviation from EIP/ERC standards that could break composability
- Design consequences that users/deployers should be aware of
- Irreversible state changes from normal usage that aren't documented
- Mechanism interactions with non-obvious emergent behavior
- **Requires**: specific code location + clear explanation. Must be a true valid observation.

---

## Do Not Report (at any severity)

- Pure gas micro-optimizations (use `!= 0` instead of `> 0`)
- Naming, NatSpec, or comment style preferences
- Redundant imports or unused error definitions
- Missing events where no off-chain system depends on them
- Centralization observations without any specific mechanism ("owner could rug")
- Theoretical issues requiring implausible preconditions (compromised compiler, >50% token supply)
- Framework behavior documented in OZ/Solmate/Solady library docs (unless wrapper adds new risk)
- Constructor parameter validation on immutables

**Note**: Common ERC-20 behaviors (fee-on-transfer, rebasing, blacklisting, pausing) are NOT implausible — if the code accepts arbitrary tokens, these are valid attack surfaces.

---

## PoC Quantification Template (Critical / High / Medium)

Before writing any Critical/High/Medium finding, answer:

```
- Who loses:      [specific role/address type]
- What they lose:  [token/ETH/governance power/safety mechanism/functionality]
- How much:       [exact formula or bound, or "service availability" for DoS]
- How often:      [once / per transaction / unbounded repeat]
- Attacker cost:   [gas only / N ETH flash loan / governance role required]
- Attacker profit: [$ value or ratio — for griefing/DoS, state "none, griefing only"]
```

For Critical/High: attacker profit must be positive. For Medium: profit can be "none" if impact is griefing, DoS, or state corruption. Not required for Low/Informational.

## Full Attack Construction — 5 Questions (Critical / High)

Answer all five before writing a Critical or High finding:

1. **Initial state**: what must be true? Is it reachable from normal operation?
2. **Attack calls**: exact functions, order, arguments, `msg.sender`
3. **State transitions**: what storage variables change at each step?
4. **Profit materialization**: which `transfer()` extracts the value? How much?
5. **Intent-implementation gap**: does this exploit a divergence between developer intent and code behavior?
