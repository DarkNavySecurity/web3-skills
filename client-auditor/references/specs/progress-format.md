# Progress Artifact Format

Progress artifacts make every phase observable while agents are still running. They are not final analysis outputs.

## Required Behavior

- **Agent first action**: as the very first file-write action before any source reading, the agent writes its assigned progress file at the path the orchestrator gave it (or the standard path below). The file starts with `Status: in-progress` and the full required frontmatter.
- The orchestrator does **not** pre-create progress skeletons. If the file does not exist when the agent starts, the agent creates it.
- Update the file at each major checkpoint and before returning.
- If blocked, write the blocker text and set `Status: blocked` instead of continuing silently.
- Do not use progress files to smuggle final findings into later phases; final authority lives in `findings/*.md`, the inventory view, the verification queue, and the report artifact.
- The orchestrator may set `Status: skipped` itself with a `Blockers:` reason when intentionally skipping a phase that has no agent (e.g. cross-subsystem when no scoped hypotheses exist).

## Required Fields

```markdown
# Progress: {phase}/{owner}

- Phase: recon | hunt | cross-subsystem | inventory | verification | depth | adversarial | report
- Owner: {agent-or-orchestrator-id}
- Status: in-progress | blocked | complete | skipped
- Started At: {ISO-8601}
- Last Updated: {ISO-8601}
- Assigned Output: ...
- Current Step: ...
- Files Read: ...
- Files Written: ...
- Decisions Made: ...
- Findings Touched: ...
- Impact / Severity Notes: ...
- Blockers: ...
- Next Checkpoint: ...
```

`Status` values:
- `in-progress` — agent is currently working
- `blocked` — agent stopped with a concrete blocker recorded in `Blockers:`; orchestrator must triage
- `complete` — agent finished, all assigned outputs written
- `skipped` — phase intentionally not run; `Blockers:` records the reason

Note: there is no `queued` state because progress files are not pre-created.

Timestamps (`Started At`, `Last Updated`) MUST be UTC ISO-8601 — produce them with `date -u +%Y-%m-%dT%H:%M:%SZ` or an equivalent locale-independent call. Local-timezone timestamps cause gate snippets that compare freshness to mis-order events.

## Standard Paths

```text
progress/recon.md
progress/hunt-{focus}.md
progress/xsub.md
progress/inventory.md
progress/verification_queue.md         # orchestrator-owned
progress/verify-{ID}.md                # one per verified finding
progress/depth-{lens}.md
progress/adversarial.md
progress/report.md
```

Use the exact `Progress Output` path from `spawn_manifest.md` for hunt agents when present. If a phase is intentionally skipped, the orchestrator writes the progress file directly with `Status: skipped`.

## Completion Gate

Each phase's completion gate (defined in `SKILL.md` as inline Bash) rejects progress files that are not terminal (`complete` | `skipped` | `blocked`) when the phase is supposed to be done. A required hunt row is stricter: `blocked` or `skipped` does not satisfy the Stage 3 gate, which requires `complete` and `Entry Points Remaining: none`. For other phases, `blocked` is terminal only when the blocker is explicit and the final report/coverage records the consequence.
