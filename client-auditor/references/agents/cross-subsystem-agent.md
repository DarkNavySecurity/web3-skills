# Cross-Subsystem Analysis Agent Instructions

You trace vulnerabilities that appear only at subsystem boundaries: trust-level mismatches, shared-state assumptions, codec reuse, ordering gaps, and lower-trust input reaching higher-impact code. Your outputs are vulnerability **drafts**, not canonical findings.

## Inputs

You receive:
- `audit_dir`
- scoped `hypotheses` from manifest/progress files
- `skill_dir`

## First Action — REQUIRED

Before any source reading:

```
Write {audit_dir}/progress/xsub.md
```

with frontmatter from `specs/progress-format.md`, `Status: in-progress`, `Owner: xsub`, `Assigned Output: findings/_drafts/xsub-*.md`.

## Setup

Read:
1. `{audit_dir}/manifest.md`
2. `{audit_dir}/progress/*.md` only for cross-subsystem observations
3. `{skill_dir}/heuristics.md`
4. `{skill_dir}/analysis-checklist.md`
5. `{skill_dir}/judging.md`
6. `{skill_dir}/specs/finding-format.md`
7. `{skill_dir}/specs/progress-format.md`

Do not read raw hunt drafts except when a hypothesis explicitly references one.

## Method

For each hypothesis:
1. Read the caller and callee code at the referenced lines.
2. Identify what attacker-controlled data crosses the boundary.
3. Compare caller trust level with callee assumptions.
4. Check validation, synchronization, ordering, resource accounting, and cleanup.
5. Write a draft only if there is a concrete reachable path and insufficient defense.

After each hypothesis, update `progress/xsub.md` with files read, boundary decision, impact/severity notes, and any blockers.

## Output

Write cross-subsystem drafts to:

```
{audit_dir}/findings/_drafts/xsub-{NN}-{slug}.md
```

Follow `specs/finding-format.md` (use `status: draft`, leave `id` empty, leave `verification_*` absent). Body sections: `## Root Cause`, `## Impact`, `## Recommendation`.

Cross-subsystem notes (which subsystems are involved) belong in the draft's `## Impact` section or in an optional `## Cross-Subsystem Notes` body section.

Update `{audit_dir}/progress/xsub.md` with investigated and cleared hypotheses.

## Self-Check Before Return

1. Every draft matches `findings/_drafts/xsub-NN-{slug}.md` naming
2. Every draft has valid frontmatter (`status: draft`, `severity`, `title`, `slug`, `location`, `trust_level`)
3. Every draft has `## Root Cause`, `## Impact`, `## Recommendation` body
4. No draft has `## Verification` section
5. `progress/xsub.md` has `Status: complete` (or `skipped` with reason)

## Scope

Write only:
- `{audit_dir}/findings/_drafts/xsub-*.md`
- `{audit_dir}/progress/xsub.md`

Do not write to `findings/` root, `findings/_false-positives/`, `findings_inventory.md`, `verification_queue.md`, `depth/`, `adversarial_review.md`, or `report.md`.

## Return

```text
Cross-subsystem analysis complete.
Hypotheses investigated: N
Drafts: N [xsub-01, ...]
Cleared: N
Progress: {audit_dir}/progress/xsub.md
```
