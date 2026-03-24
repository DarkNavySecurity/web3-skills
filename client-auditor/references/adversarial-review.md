# Adversarial Review Protocol

A structured stress-testing technique for high-severity findings. Three perspectives — Red Team, Blue Team, Judge — challenge a finding to calibrate its severity before final reporting.

Initial severity ratings are systematically biased toward over-severity. This protocol is the most effective calibration tool.

---

## When to Apply

Use adversarial review for findings scored HIGH or above (confidence ≥70). For CRITICAL findings, always apply. For MEDIUM findings, apply when the finding is borderline or the impact assessment is uncertain.

Adversarial review is thorough but expensive. Apply it to the highest-impact qualifying findings. Prioritize findings where severity is most uncertain or impact is highest.

---

## Red Team Perspective

**Goal**: Prove the finding IS exploitable. Maximize the attack's impact.

Questions to answer:

1. **Attack construction** — What is the cheapest, simplest path to trigger this? What attacker capabilities are required (any peer, staked validator, admin, physical access)? Describe the step-by-step attack with specific message types, parameter values, and timing.

2. **Mitigation challenges** — For each claimed defense: read the exact code implementing it. Can it be circumvented (race condition, different entry path, parameter combination that bypasses the check)? Is it actually enforced (compiled in, enabled by default, applies to this code path)? Can it be overwhelmed (rate limit too high, bound too generous, cleanup too slow)?

3. **Quantitative attack model** — Cost to the attacker (resources, time, stake). Damage to the victim (concrete numbers). Cost ratio: attacker_cost / victim_damage. How many attackers need to collude? Detection probability during the attack?

4. **Escalation paths** — Can this be chained with other findings? Does it weaken defenses protecting against other attacks? Can the impact be amplified through repetition?

Conclude with: **EXPLOITABLE**, **PARTIALLY EXPLOITABLE**, or **THEORETICAL** — with a one-paragraph justification citing specific code lines.

---

## Blue Team Perspective

**Goal**: Prove the finding is NOT exploitable, or is less severe than claimed. Protect the codebase's reputation fairly.

Questions to answer:

1. **Defense inventory** — List every existing mitigation, even partial: rate limiting (per-IP, per-peer, per-message-type, global), size bounds, authentication requirements, resource caps, load shedding, cleanup mechanisms. For each, cite the exact code location and explain its effectiveness.

2. **Attack cost analysis** — What must the attacker invest (network connections, stake, time, custom tooling)? What is the detection probability (logs, monitoring, peer reputation)? What are the consequences if detected (disconnection, banning, slashing)?

3. **Environmental constraints** — Does this require non-default configuration? Public exposure of typically-private interfaces? Does the default deployment topology prevent this? Are there operational practices that mitigate it?

4. **Impact reassessment** — Is the claimed impact realistic or worst-case theoretical? What is the actual blast radius (one node, one shard, all nodes)? Is recovery automatic or manual? Can honest nodes route around the damage?

Conclude with: **NOT EXPLOITABLE**, **CONSTRAINED**, or **EXPLOITABLE AS DESCRIBED** — with a one-paragraph justification citing specific code lines.

---

## Judge Perspective

**Goal**: Verify both perspectives against source code. Render a final verdict.

Process:

1. **Verify Red Team claims** — For each factual claim, find the code line that confirms or denies it. Mark: VERIFIED / REFUTED / UNVERIFIABLE. If refuted, explain what the code actually does.

2. **Verify Blue Team claims** — Same process. Defense claims are especially important to verify — a claimed rate limit that doesn't actually exist changes the entire analysis.

3. **Resolve disputes** — For each point where Red and Blue disagree, read the actual code path end-to-end. Determine which interpretation is correct. Cite specific references.

4. **Recalculate severity** — Using verified facts only (not claimed facts), recalculate the confidence score using the judgment criteria. Apply only deductions supported by verified Blue Team claims. Do NOT apply deductions for defenses that were refuted.

5. **Final verdict** — One of:
   - **TRUE**: Exploitable as described. Maintain or increase severity.
   - **PARTIAL**: Exploitable but with significant constraints. Adjust severity.
   - **FALSE**: Not exploitable or by-design behavior. Downgrade to Info or remove.

Include: final severity, final confidence score, one-paragraph reasoning with code references.

---

## Application Notes

- The three perspectives should be applied sequentially by a single analyst (or single agent) so that Blue Team reads Red Team's output and the Judge reads both. Running them separately loses the shared context that makes the protocol effective.
- Red Team and Blue Team must both read the actual source code — not just reason about what the code "probably does."
- The Judge must independently verify factual claims. Trust neither Red nor Blue — trust the code.
- If the Red and Blue perspectives substantially agree, the Judge pass can be brief. If they disagree on facts, the Judge pass is the most important part.
