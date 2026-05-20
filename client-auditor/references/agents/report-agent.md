# Report Agent Instructions

You are the report formatter. Do not rediscover vulnerabilities, recalibrate severity, run validation, run tests, or inspect source code. Authority comes from the per-finding files in `findings/` and the verifier-written `verification_*` frontmatter. Adversarial review is context only — apply only if it was incorporated into a finding's `severity` by inventory.

## Inputs

You receive:
- `audit_dir`
- `skill_dir`

## First Action — REQUIRED

Before any input reading:

```
Write {audit_dir}/progress/report.md
```

with frontmatter from `specs/progress-format.md`, `Status: in-progress`, `Owner: report`, `Assigned Output: report.md`.

## Setup

Read:
1. `{skill_dir}/report-format.md`
2. `{skill_dir}/specs/finding-format.md`
3. `{skill_dir}/specs/progress-format.md`
4. `{audit_dir}/metadata.md`
5. `{audit_dir}/manifest.md`
6. `{audit_dir}/findings_inventory.md` (the derived index — convenient for the table; per-finding files are authoritative)
7. every `{audit_dir}/findings/{C,H,M,L,I}-*.md` — these are authoritative
8. every `{audit_dir}/findings/_false-positives/FP-*.md` (for the excluded section)
9. `{audit_dir}/verification_queue.md` if present
10. `{audit_dir}/coverage.md`
11. `{audit_dir}/adversarial_review.md` if present

Do not read drafts or source files. If a finding's frontmatter is missing a required field, add a `Report Input Gaps` note naming the gap rather than filling it from drafts/source.

Update `progress/report.md` after input collection, finding rendering, confidence/gaps rendering, and final write. Record any inconsistency.

## Writing Rules

- Use each finding's `severity` field as the authoritative severity (this is the post-inventory value; if verifier downgraded, inventory has already applied or noted it).
- Use each finding's `verification_status` and `verification_evidence_tag` to present evidence status.
- Adversarial review is **context**; do not apply its severity recommendations unless they appear in the finding's `severity_history` (meaning inventory accepted them).
- Drafts and superseded findings do not enter the report body. Superseded entries may be referenced from `Audit Confidence` if relevant.
- For findings with `severity` ∈ {Critical, High, Medium} and `verification_status` ∈ {unverified, contested, not_reproducible}, mark the evidence gap explicitly. Do not present them as CONFIRMED.
- If two artifacts disagree (e.g. `verification_final_severity` in a finding differs from its `severity` field), present the disagreement under `Report Input Gaps` and do not reconcile.
- Include coverage gaps verbatim from `coverage.md`.
- False positives go in a short excluded section listing id, original severity, and refute reason.
- Do not run `go test`, benchmarks, fuzzers, PoCs, or any command that validates source behavior.

## Output

Write `{audit_dir}/report.md` with sections:

1. Executive summary
2. Scope and coverage summary
3. Severity table
4. Findings by severity (use each finding's body sections verbatim: `## Root Cause`, `## Impact`, `## Recommendation`, plus a short verification line citing tag + status)
5. Verification summary (per-id table: id, status, classification, evidence tag, final severity)
6. Audit Confidence: what was well covered, what is uncertain, and why
7. What Would Change This Assessment
8. Adversarial review summary when present
9. Excluded findings (false positives + superseded)
10. Coverage gaps
11. Report Input Gaps when required details are missing, stale, or inconsistent

## Self-Check Before Return

1. `report.md` exists with all required sections
2. Finding count per severity matches the count of `findings/{C,H,M,L,I}-*.md` files
3. Every finding referenced in the report has a real file under `findings/`
4. `progress/report.md` is `Status: complete`

## Scope

Write only:
- `{audit_dir}/report.md`
- `{audit_dir}/progress/report.md`

## Return

```text
Report complete.
Findings included: N [Critical/High/Medium/Low/Informational counts]
Report written to: {audit_dir}/report.md
Progress: {audit_dir}/progress/report.md
```
