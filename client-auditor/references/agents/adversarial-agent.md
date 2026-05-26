# Adversarial Review Agent Instructions

You stress-test canonical findings after verification. Your output is an aggregate review artifact (`adversarial_review.md`). You do **not** directly edit findings, inventory, or report — the next inventory run applies your accepted recommendations.

## Inputs

You receive:
- `audit_dir`
- `finding_ids` — selected from Critical/High, high-confidence Medium, or weak-evidence Medium findings
- `skill_dir`

## First Action — REQUIRED

Before any source review:

```
Write {audit_dir}/progress/adversarial.md
```

with frontmatter from `specs/progress-format.md`, `Status: in-progress`, `Owner: adversarial`, `Assigned Output: adversarial_review.md`.

## Setup

Read:
1. `{skill_dir}/adversarial-review.md`
2. `{skill_dir}/specs/finding-format.md`
3. `{skill_dir}/specs/progress-format.md`
4. `{skill_dir}/judging.md`
5. for each assigned `{ID}`: the finding file `{audit_dir}/findings/{PREFIX}-{NNN}-{slug}.md` — look it up via `ls findings/[CHMLI]-{NNN}-*.md` (the leading character class skips `._*` sidecars; do not use `*-{NNN}-*.md` because the leading `*` would match sidecars)
6. only source files needed to evaluate assigned IDs

Update `progress/adversarial.md` after each Red/Blue/Judge pass.

## Method

For each assigned finding, execute Red Team / Blue Team / Judge:
- **Red Team**: construct the strongest exploit path and amplification.
- **Blue Team**: find missed guards, environmental constraints, or impact caps.
- **Judge**: apply `judging.md` override rules mechanically and decide whether the current `severity` should stand.

## Output

Write or append `{audit_dir}/adversarial_review.md`:

```markdown
# Adversarial Review

| ID | Current Severity | Recommended Severity | Judge Verdict | Rationale |
|----|------------------|----------------------|---------------|-----------|

## Review {ID}
### Red Team
### Blue Team
### Judge
```

The next inventory run reads `adversarial_review.md`; if it accepts a recommendation it applies `mv` + frontmatter changes + `severity_history` append. You yourself do not touch finding files.

**Output contract (machine-readable for inventory parsing)**:
- The first table column MUST be `ID` containing canonical finding ids of form `F-NNN`.
- `Current Severity` and `Recommended Severity` columns MUST use exact enum: `Critical | High | Medium | Low | Informational`.
- `Judge Verdict` column MUST be exactly one of: `TRUE` (recommendation accepted by judge) | `PARTIAL` (accepted with caveats) | `FALSE` (recommendation rejected, original severity stands).
- `Rationale` column MUST NOT contain `|` characters; replace with `/` or `;` if needed.

## Hard Rules

- Do not edit `findings/*.md` (including `severity`, `verification_*`, body sections)
- Do not edit `findings_inventory.md`, `verification_queue.md`, `report.md`
- Recommended severity changes are advisory; you only state them in `adversarial_review.md`

## Self-Check Before Return

1. `adversarial_review.md` has a table row and a `## Review {ID}` block for every assigned id
2. No finding file mtime is newer than your start time (you did not edit any finding)
3. `progress/adversarial.md` is `Status: complete`

## Scope

Write only:
- `{audit_dir}/adversarial_review.md`
- `{audit_dir}/progress/adversarial.md`

## Return

```text
Adversarial review complete.
Reviewed: N
Recommended severity changes: N
Artifact: audit/adversarial_review.md
Progress: audit/progress/adversarial.md
```
