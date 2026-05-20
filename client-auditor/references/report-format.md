# Report Format

What a strong audit report looks like. The key properties: findings are organized by severity, each finding has enough detail to reproduce and verify, and coverage is honestly documented. Adapt the structure to fit the specific audit.

---

## Report Structure

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

## Individual Finding

A well-structured finding contains enough detail for someone else to reproduce, verify, and fix it. Here is what that looks like:

```markdown
### [F-NNN]: [Short Title]

| Field | Value |
|-------|-------|
| **Severity** | [Critical / High / Medium / Low / Informational] |
| **Confidence** | [0-100] |
| **Source Drafts** | [bare draft IDs from `source_candidates` frontmatter, e.g. `p2p-01, xsub-03`] |
| **Trust Level** | [1-7, see `routing/trust-boundaries.md`] |
| **Evidence Tag** | [[TRACE] / [BUILD-PASS] / [TEST-PASS] / [FUZZ-PASS] / [DIFF-PASS] / [SPEC-PASS] / [UNVERIFIED]] |
| **Verification Status** | [confirmed / contested / refuted / not_reproducible / unverified] |
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

Final report finding IDs are canonical `F-NNN` ids drawn from each finding's `id:` frontmatter field. These are stable across severity changes — the file *name* on disk has a severity prefix (`{C|H|M|L|I}-NNN-{slug}.md`) but the cross-reference id in the report does not. Hunt-time draft IDs (e.g. `p2p-01`, `xsub-03`, `depth-network-surface-02`) are provenance only and appear in the `Source Drafts` field. Do not present raw draft IDs as final finding IDs.

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

When deep mode is used and inventory incorporates adversarial recommendations:

```markdown
| ID | Inventory Severity | Adversarial Recommendation | Inventory Resolution | Reasoning |
|----|--------------------|----------------------------|----------------------|-----------|
| [F-NNN] | [severity] | [recommended severity] | [accepted/rejected/deferred] | [summary] |
```

Findings not selected for adversarial review: note as "not adversarially reviewed" with inventory severity retained.

---

## What Makes Findings Actionable

Findings that reference specific code locations and include concrete numbers are more actionable than vague descriptions:

- **Specificity** — "No limit on `message.items_count()` in handler path" is actionable; "unbounded input" is not
- **Code references** — Findings that cite `file:line` can be verified and fixed; findings without them cannot
- **Quantitative math** — Resource findings with concrete calculations (cost × rate × time = impact) are convincing; "could be large" is not
- **Missing defenses** — Listing what should exist but doesn't gives developers a clear fix target
- **Fact vs judgment** — Descriptions that state facts and recommendations that state opinions are clearer than mixing both
- **Source drafts** — Preserve draft IDs as provenance while using `F-NNN` as final report IDs
