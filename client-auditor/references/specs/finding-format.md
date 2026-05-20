# Finding Format

Findings are the authoritative artifact for the audit. Every finding lives in its own file under `audit/findings/`. The `findings_inventory.md` file is a derived view, not authority.

## File Path

| State | Path |
|---|---|
| draft (pre-promotion) | `audit/findings/_drafts/{focus}-{NN}-{slug}.md` |
| active / verified / superseded | `audit/findings/{PREFIX}-{NNN}-{slug}.md` |
| false-positive | `audit/findings/_false-positives/FP-{NNN}-{slug}.md` |

Where:
- `PREFIX` ∈ {`C`, `H`, `M`, `L`, `I`} reflects current severity (Critical|High|Medium|Low|Informational)
- `NNN` is a zero-padded three-digit global sequence
- `slug` is lowercase-kebab-case derived from the title
- `focus` is the hunt/xsub/depth focus that produced the draft

## Identity Invariants

- `id` (frontmatter field) is globally unique, **never reused, never renumbered**
- `id` is independent of `PREFIX`: severity changes rename the file but `id` stays
- The numeric part of `id` matches the `NNN` in the filename (`id: F-{NNN}` ↔ filename `{PREFIX}-{NNN}-{slug}.md`)
- `slug` may change with title edits; `id` does not
- Other artifacts (`verification_queue.md`, `report.md`, cross-references) reference findings by `id` only, not by filename — this makes severity changes harmless to cross-refs

## Lifecycle States

| `status` | Location | Transitioned in by | Meaning |
|---|---|---|---|
| `draft` | `findings/_drafts/` | hunt, cross-subsystem, depth | raw output, awaiting inventory promotion |
| `active` | `findings/` | inventory (from draft) | promoted, canonical id assigned, awaiting/undergoing verify |
| `verified` | `findings/` | verifier (sets `verification_status` ∈ {confirmed, contested}) | reachability + guard analysis complete |
| `superseded` | `findings/` (file remains) | inventory | duplicate absorbed into another finding; frontmatter records `superseded_by` |
| `false-positive` | `findings/_false-positives/` | inventory (on verifier `verification_status: refuted`) | not exploitable; FP- prefix |

Transitions:
- hunt/xsub/depth → write to `_drafts/`, `status: draft`
- inventory → `mv` to `findings/`, `status: active`, assign canonical `id` and `confidence`
- verifier → edit in place, set `verification_*` fields, `status: verified` (unless `verification_status: refuted`)
- inventory (rerun) → on `verification_status: refuted` → `mv` to `_false-positives/`, prefix changed to `FP-`, `status: false-positive`
- inventory (rerun, merge) → loser → `status: superseded`, frontmatter `superseded_by: F-{NNN}`; file kept in `findings/` as audit trail
- inventory (rerun, severity change) → `mv` filename to new `PREFIX-`, update `severity` field, append to `severity_history`

File moves use plain `mv`. `git mv` is the user's responsibility — `audit/` may not be a git-tracked directory.

## Required Frontmatter

```yaml
---
# === Identity ===
id: F-NNN                   # globally stable; assigned by inventory on first promotion
title: "..."
slug: kebab-case-slug

# === Severity (current + history) ===
severity: Critical | High | Medium | Low | Informational
confidence: 0-100              # judging.md confidence score; assigned by inventory, may be updated on rerun
severity_history:
  - by: <agent-or-role>        # all four keys are REQUIRED in every entry; reason may be "" but must be present
    severity: <enum>
    at: <ISO-8601>
    reason: "..."
  # one entry per change; first entry is hunt's initial estimate

# === Lifecycle ===
status: draft | active | verified | superseded | false-positive
reportable: true | false
superseded_by: F-NNN        # required iff status == superseded
verification_required: true | false
verification_reason: "..."  # required iff verification_required == false

# === Provenance ===
source_candidates: [<hunt-local-ID>, ...]   # bare draft IDs that were merged in
trust_level: 1..7                          # see routing/trust-boundaries.md; 1 = largest attacker pool
location:
  file: "<path>"
  line: "<N>" | "<start>-<end>"
  function: "<name>"
pattern_refs: [PAT-NN, ...]   # optional, references references/patterns/

# === Verification (verifier-owned; absent until verify phase runs) ===
verification_status: unverified | confirmed | contested | refuted | not_reproducible
verification_classification: confirmed | reachable-but-impact-contested | guarded | not-reproducible | environment-blocked | refuted
verification_evidence_tag: "[TRACE]" | "[BUILD-PASS]" | "[TEST-PASS]" | "[FUZZ-PASS]" | "[DIFF-PASS]" | "[SPEC-PASS]" | "[UNVERIFIED]"
verification_final_severity: Critical | High | Medium | Low | Informational
verification_poc_attempted: true | false
verification_poc_blocker: "..."   # required iff verification_poc_attempted == false
verification_at: <ISO-8601>
verification_by: "<agent-id>"

# === Audit metadata ===
found_by: agent | human
found_at: <ISO-8601>
---
```

Field rules:
- `severity` reflects the **current** authoritative severity. Verifier never edits this directly — verifier sets `verification_final_severity`; inventory reads it on rerun and decides whether to change `severity` (with `mv` + history append).
- `severity_history` is append-only. Every change to `severity` adds an entry.
- `superseded_by` and `verification_reason` are conditionally required (see comments).
- `verification_*` fields are absent until verify runs. Once verifier writes them, they are owned by verifier; inventory may read but not edit (except `verification_required`, which inventory owns).

## Required Body Sections

```markdown
## Root Cause
<one to several paragraphs>

## Impact
<reachability description + concrete harm>

## Recommendation
<fix guidance>

## Verification           # ← verifier-written; absent in drafts
### Reachability Trace
### Guard Analysis
### Evidence
### Decision
```

Sections owned by:
- hunt / inventory: `Root Cause`, `Impact`, `Recommendation`
- verifier: the entire `## Verification` block (all four subsections)

## Ownership Boundaries

| Agent | May write | May read |
|---|---|---|
| hunt / cross-subsystem / depth | own draft file in `_drafts/` only | source code, pattern files |
| inventory | promote drafts (`mv` + new frontmatter), modify `severity` / `confidence` / `severity_history` / `status` / `reportable` / `verification_required` / `superseded_by` of any `findings/*.md`, generate `findings_inventory.md` (derived view), move REFUTED to `_false-positives/` | all of `findings/`, `findings/_drafts/`, `findings/_false-positives/`, `depth/`, `findings_inventory.md` (previous), `adversarial_review.md` (for accepted recommendations) |
| verifier | one assigned finding file: `verification_*` frontmatter fields + `## Verification` body block | the one assigned finding, source code |
| adversarial | recommend changes by writing `adversarial_review.md` only; **never** edits findings directly | all findings |
| report | none (read-only) | all findings, inventory view, verification queue, adversarial review |

## Dedup Rules (inventory)

Merge two findings into one only when **all** of:
1. Same root cause and same fix pattern
2. Same affected semantics (not just shared file)
3. No semantic loss in merging the descriptions

When merging, pick canonical = the one with the most evidence / lowest `id`. Others → `status: superseded`, `superseded_by: <canonical-id>`. File stays in place as audit trail.

When in doubt, keep separate and add a `related_findings:` list to both.

## Severity Authority

Inventory applies `judging.md` rules mechanically. Severity changes always:
1. Update `severity` field
2. Append to `severity_history` (all four keys: `by`, `severity`, `at`, `reason`)
3. `mv` filename to new `PREFIX-`

`reportable: true` is default for any `severity` in {Critical, High, Medium} unless explicitly downgraded with a reason.

`verification_required: true` is default for any `severity` in {Critical, High, Medium} when `status != verified` and `status != false-positive`.
