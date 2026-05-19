# Contributing to DARKNAVY Web3 Skills

## Pull Request Process

1. Fork the repository and branch from `main`.
2. Make your changes — attack patterns, agent prompts, reference files, knowledge docs, report format, or bug fixes.
3. Keep your branch up to date with `main`.
4. Do not edit `VERSION` files — they are bumped automatically on merge via CI.
5. Submit a PR and allow up to five business days for review.

### PR Checklist

- [ ] Follows all rules below
- [ ] Tested locally with Claude Code or Codex invocation

## What to Contribute

**Attack patterns:** Add new vulnerability pattern families or refine existing ones in the `references/patterns/` files. Use the established format and explain the real-world bug class it addresses.

**Analysis techniques:** Improve analysis checklists, heuristic strategies, or adversarial review protocols in reference files.

**Agent prompts:** Refine SKILL.md instructions for better triage accuracy, fewer false positives, and more actionable output.

**Report formatting:** Enhance report templates and resolve formatting inconsistencies. Nice UI designs are welcome.

**Bug fixes:** If the skill produces inaccurate output, submit a PR or open an issue.

## Rules

- **One skill, one purpose.** Don't overload a skill with unrelated capabilities.
- **No concrete examples in SKILL.md.** Concrete examples leak context bias into agent prompts.
- **No secrets, credentials, RPC URLs, or wallet addresses.**
- **No fabricated outputs.** Sample output must reflect real model responses.
- **Knowledge over process.** Skills should provide expertise the agent can apply with judgment, not rigid step-by-step pipelines.
- **Reference files are lazy-loaded.** SKILL.md should tell the agent which reference files exist and when to read them — not require reading everything upfront.

## Version Management

- Each skill has an integer `VERSION` file starting at `1`.
- A GitHub Actions workflow watches for changes under each skill directory.
- On merge to `main`, if any file changed (excluding `VERSION` itself), the workflow increments the version and commits with `[skip ci]`.
- Skills can optionally check their local version against the remote `VERSION` file to warn users about updates.

## Testing

```bash
claude                          # start Claude Code
> /skill-name target-path       # invoke the skill
```

## Reporting Bugs

Open an issue with:
- Which skill and how you invoked it (CLI, VS Code, Cursor)
- Claude model version used
- Input provided and actual output received
- Expected output
