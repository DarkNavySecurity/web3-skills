# Report Format

What a strong audit report looks like. The key properties: findings are organized by severity, each finding has enough detail to reproduce and verify, and coverage is honestly documented. Adapt the structure to fit the specific audit.

---

## Report Structure (example)

```markdown
# [Project Name] Security Audit Report

**Audit Date:** [YYYY-MM-DD]
**Target:** [repository, branch/commit]
**Scope:** [subsystems analyzed, lines of code reviewed]

---

## Executive Summary

[2-4 paragraphs covering:]
- What was analyzed and what was not
- Finding counts by severity
- Key conclusions: the 3-5 most important findings or observations
- Adversarial review results (if deep mode was used)

---

## Severity Summary

| Severity | Count | Key Areas |
|----------|-------|-----------|
| Critical | [N] | [affected subsystems] |
| High | [N] | [affected subsystems] |
| Medium | [N] | [affected subsystems] |
| Low | [N] | [affected subsystems] |
| Info | [N] | [affected subsystems] |
| **Total** | **[N]** | |

---

## Findings

### CRITICAL Severity
### HIGH Severity
### MEDIUM Severity
### LOW Severity
### INFORMATIONAL

[Each section: summary table, then detailed findings]

---

## Coverage Summary

[What was analyzed, what was not, and why]

---

## Adversarial Review Summary (if applicable)

[Table of reviewed findings with verdicts]
```

---

## Individual Finding (example)

A well-structured finding contains enough detail for someone else to reproduce, verify, and fix it. Here is what that looks like:

```markdown
### [ID]: [Short Title]

| Field | Value |
|-------|-------|
| **Severity** | [Critical / High / Medium / Low / Info] |
| **Confidence** | [0-100] |
| **Pattern** | [P1-P20 ID and name, or "None — heuristic finding"] |
| **Location** | [file:line_start-line_end] |
| **Entry Point** | [How an attacker reaches this code] |
| **Impact** | [What happens if exploited] |

#### Description

[2-4 sentences. What the code does, what it fails to do, what an attacker achieves.]

#### Trigger Scenario

1. Attacker [action] via [entry point]
2. Message/request reaches [handler] at [file:line]
3. [Missing check / incorrect logic] allows [bad state]
4. Result: [concrete impact with numbers]

#### Quantitative Assessment

[Resource consumption math, if applicable:]
- Cost per unit: [bytes / reads / cycles]
- Units per message: [calculation]
- Rate limit: [messages before cutoff]
- Total impact: [resource × units × messages]
- Time to impact: [total / capacity]

#### Existing Mitigations

- [Mitigation 1]: [effectiveness assessment]
- [Mitigation 2]: [effectiveness assessment]

#### Missing Defenses

- [ ] [Defense 1]: [why it matters]
- [ ] [Defense 2]: [why it matters]

#### Recommendation

[Concrete fix, 1-3 sentences, referencing specific code locations.]

#### Adversarial Review (if applicable)

| Role | Verdict | Key Argument |
|------|---------|-------------|
| Red Team | [assessment] | [core argument] |
| Blue Team | [assessment] | [core argument] |
| **Judge** | **[TRUE / PARTIAL / FALSE]** | [reasoning with code refs] |
```

---

## Finding ID Convention

Format: `[PATTERN_ID]-[SEQUENCE]`

- `P9-01` — First finding in P9 (P2P Resource Exhaustion)
- `P1-03` — Third finding in P1 (Input Panic)
- `P17-01` — First finding in P17 (Memory Safety)
- `HEURISTIC-01` — First heuristic finding (no pattern match)

When a finding maps to multiple patterns, use the primary pattern for the ID and note secondary patterns in the body.

---

## Coverage Summary Format

The coverage summary describes work done, not a metric to optimize:

```markdown
## Coverage Summary

### Analyzed
- [Subsystem 1]: [entry points examined, what was checked]
- [Subsystem 2]: [entry points examined, what was checked]

### Not Analyzed
- [Subsystem 3]: [why — out of scope, insufficient context, lower risk priority]
- [Subsystem 4]: [why]

### Partially Analyzed
- [Subsystem 5]: [what was checked, what remains]
```

---

## Adversarial Review Summary Table

When deep mode is used and findings are reclassified:

```markdown
| ID | Original Severity | Final Severity | Judge Verdict | Reasoning |
|----|-------------------|----------------|---------------|-----------|
| [ID] | HIGH | [new severity] | [TRUE/PARTIAL/FALSE] | [summary] |
```

Findings not selected for adversarial review: note as "not adversarially reviewed" with initial severity retained.

---

## What Makes Findings Actionable

Findings that reference specific code locations and include concrete numbers are more actionable than vague descriptions:

- **Specificity** — "No limit on `message.items_count()` in handler path" is actionable; "unbounded input" is not
- **Code references** — Findings that cite `file:line` can be verified and fixed; findings without them cannot
- **Quantitative math** — Resource findings with concrete calculations (cost × rate × time = impact) are convincing; "could be large" is not
- **Missing defenses** — Listing what should exist but doesn't gives developers a clear fix target
- **Fact vs judgment** — Descriptions that state facts and recommendations that state opinions are clearer than mixing both
- **Pattern IDs** — Using P1-P20 enables cross-referencing across findings and future audits
