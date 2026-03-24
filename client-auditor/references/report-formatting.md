# Report Formatting Guide

This document defines the output format for the blockchain client auditor skill. All findings are formatted consistently to enable comparison, deduplication, and handoff to development teams.

---

## Report Structure

```markdown
# [Project Name] Security Audit Report

**Audit Date:** [YYYY-MM-DD]
**Target:** [Project description], [branch/commit]
**Methodology:** Pattern-based vulnerability analysis using 20 historical
blockchain client attack pattern families (107 bugs across 20+ ecosystems),
with structured adversarial review for high-severity findings.

---

## Executive Summary

[2-4 paragraphs covering:]
- Scope: lines of code reviewed, subsystems covered, entry points analyzed
- Top-level results: finding counts by severity
- Key conclusions: 3-5 bullet points on the most important findings
- Adversarial review results (if `deep` mode was used)

---

## Findings by Severity

### CRITICAL Severity ([N] findings)
### HIGH Severity ([N] findings)
### MEDIUM Severity ([N] findings)
### LOW Severity ([N] findings)
### INFORMATIONAL ([N] findings)

[Each section contains a summary table followed by detailed findings]
```

---

## Individual Finding Format

Each finding uses this template:

```markdown
### [ID]: [Short Title]

| Field | Value |
|-------|-------|
| **Severity** | [Critical/High/Medium/Low/Info] |
| **Confidence** | [0-100] |
| **Pattern** | [P1-P20 ID and name] |
| **Location** | [file:line_start-line_end] |
| **Entry Point** | [How an attacker reaches this code] |
| **Impact** | [What happens if exploited] |

#### Description

[2-4 sentences explaining the vulnerability. Start with what the code does,
then what it fails to do, then what an attacker can achieve.]

#### Trigger Scenario

[Step-by-step attack scenario:]
1. Attacker [action] via [entry point]
2. Message/request reaches [handler] at [file:line]
3. [Missing check / incorrect logic] allows [bad state]
4. Result: [concrete impact with numbers if applicable]

#### Quantitative Assessment

[If applicable — resource consumption math:]
- Cost per unit: [bytes/reads/cycles]
- Units per message: [calculation]
- Messages before limit: [credit system / rate limit math]
- Total impact: [resource × units × messages]
- Time to impact: [total / capacity]

#### Existing Mitigations

[List every existing defense, even partial:]
- [Mitigation 1]: [effectiveness assessment]
- [Mitigation 2]: [effectiveness assessment]

#### Missing Defenses

[List defenses that SHOULD exist but do NOT:]
- [ ] [Defense 1]: [why it matters]
- [ ] [Defense 2]: [why it matters]

#### Recommendation

[Concrete fix recommendation, 1-3 sentences. Reference specific code locations.]

#### Adversarial Review (if applicable)

| Role | Verdict | Key Argument |
|------|---------|-------------|
| Red Team | [Summary] | [Core argument] |
| Blue Team | [Summary] | [Core argument] |
| **Judge** | **[TRUE/PARTIAL/FALSE]** | [Reasoning with code refs] |
```

---

## Finding ID Convention

Format: `[PATTERN_ID]-[SEQUENCE]`

Examples:
- `P9-01` — First finding in P9 (P2P Resource Exhaustion) family
- `P1-03` — Third finding in P1 (Input Panic) family
- `P17-01` — First finding in P17 (Memory Safety) family
- `RPC-01` — First finding specific to RPC handlers (when no pattern family fits exactly)
- `B-01` — First finding in batch/transaction processing (custom category)

When a finding maps to multiple patterns, use the primary pattern for the ID and note secondary patterns in the finding body.

---

## Summary Tables

### Severity Summary Table (top of report)

```markdown
| Severity | Count | Key Areas |
|----------|-------|-----------|
| Critical | [N] | [affected subsystems] |
| High | [N] | [affected subsystems] |
| Medium | [N] | [affected subsystems] |
| Low | [N] | [affected subsystems] |
| Info | [N] | [affected subsystems] |
| **Total** | **[N]** | |
```

### Per-Section Table (before detailed findings)

```markdown
| ID | Area | Description | Confidence | Judge Verdict |
|----|------|-------------|------------|---------------|
| [ID] | [subsystem] | [short description of finding] | [score] | [verdict if reviewed] |
```

---

## Adversarial Review Summary Table

When `deep` mode is used and findings are reclassified:

```markdown
### Reclassified from HIGH (after adversarial review)

| ID | Original | Final | Area | Description | Judge Reasoning |
|----|----------|-------|------|-------------|-----------------|
| [ID] | HIGH | [new severity] | [subsystem] | [short description] | [reasoning summary] |
```

---

## Style Guidelines

1. **Be specific:** "No limit on `message.items_count()` in handler path" not "unbounded input"
2. **Include code references:** Every finding must reference at least one `file:line`
3. **Compute numbers:** Resource findings must include quantitative math, not just "could be large"
4. **List what's missing:** Always include the "Missing Defenses" section even if empty
5. **Separate fact from judgment:** Description states facts; Recommendation states opinion
6. **No external URLs:** Do not include links to GitHub, blog posts, or external resources in findings
7. **Anonymize pattern references:** Reference patterns by ID (P1-P20) not by the original case study names
