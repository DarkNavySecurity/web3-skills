# Report Formatting

## Report Path

Save the report to `./{project-name}-contract-auditor-{timestamp}.md` in the current working directory, where `{project-name}` is the basename of the current working directory and `{timestamp}` is `YYYYMMDD-HHMMSS` at scan time.

Example: if cwd is `/home/user/myprotocol`, write to `./myprotocol-contract-auditor-20260320-143022.md`.

---

## Critical Output Rules

- Output **plain markdown only**. Do NOT wrap the report in an outer code block.
- Use native markdown elements: `##` headers, `>` blockquotes, `---` separators, ` ```diff ` fences.
- Do not add any footer, disclaimer, or closing note after the last finding.
- Do not re-draft or re-summarize findings — output them directly in the format below.

---

## Section 1 — Report Header

```
# 🔐 contract-auditor — <ContractName or repo name>
```

Immediately below the title, one line:

```
`File1.sol` · `File2.sol` · <mode> · <YYYY-MM-DD>
```

- List every in-scope file as a backtick span, separated by ` · `
- `<mode>` is one of: `default` / `DEEP` / `filename`
- `<YYYY-MM-DD>` is today's date

---

## Section 2 — Findings Summary Table

Immediately after the header line, before any findings:

```
| # | Severity | Title |
|---|----------|-------|
| 1 | Critical | Title of finding 1 |
| 2 | High     | Title of finding 2 |
| 3 | Medium   | Title of finding 3 |
| 4 | Low      | Title of finding 4 |
| 5 | Info     | Title of finding 5 |
```

Rules:
- Sort by severity: Critical → High → Medium → Low → Design Advisory → Informational.
- Within the same severity, order by impact (most impactful first).
- Titles must match the `##` heading titles exactly.
- Use short labels in the table: `Critical`, `High`, `Medium`, `Low`, `Design`, `Info`.
- If there are no findings, include one row: `| - | None | No confirmed findings |`.

Then `---` before the coverage summary.

---

## Section 2.5 — Coverage Summary

After the findings summary table and before the findings section, include:

### Coverage

| Contract | Functions Analyzed | Analysis |
|----------|-------------------|----------|
| <Contract.sol> | N / M | DFS by Agent 1 (deposit paths) |
| <Contract.sol> | N / M | DFS by Agent 2 (redeem paths); boundary-check by Agent 1 |

- M = total entry points from the context map (shared ground truth across all agents)
- N = entry points with at least one line-by-line DFS pass (from agent coverage logs)
- "boundary-check" = agent followed a call into this contract but only verified the interface, state architecture, and cross-contract dependency surface, not full internals. Boundary checks do not count toward N.
- If any contract has coverage < 80%, flag it as a gap
- If follow-up analysis was spawned for gaps, note what it targeted

Then `---` before the findings section.

---

## Section 3 — Findings

Each finding follows this exact structure, separated by `---`:

~~~~markdown
## [Severity] N. Title of Finding

> `EntryContract.entryFunction(params)`
>   → `calledFunction()`
>     → `vulnerableOperation()` → **outcome**

`ContractName.functionName` · guard: **none**

**Precondition** — <what the attacker must control or satisfy>

**Impact** — <what is lost or broken if exploited>

**Description** — <one sentence: what the code does wrong and how it is exploited>

**Assumptions** — <conditions assumed but not verified; what validation would confirm or disprove>

```diff
- the vulnerable line or lines
+ the fixed line or lines  // brief reason why this fixes it
```

---
~~~~

### 3a — The `##` heading

Format: `## [Severity] N. Title`

- `[Severity]` is one of: `[Critical]`, `[High]`, `[Medium]`, `[Low]`, `[Design Advisory]`, `[Informational]`
- `N` is the sequential finding number
- Title is concise (≤10 words), describes the root cause not the symptom

Good: `## [High] 1. Unchecked Return Value Enables Double Withdrawal`
Bad:  `## [High] 1. Missing Input Validation in withdraw Function`

### 3b — The attack path blockquote

Use indentation to show call depth. Each `>` line is one level in the call chain.

Rules:
- Every function name is wrapped in backticks: `` `withdraw(amount)` ``
- Indent with 2 spaces per call depth level after `> `
- Arrows ` → ` connect calls at the same depth, or prefix a deeper call
- The final outcome is **bold plain text**: → **drain pool**
- Do not write prose in the blockquote. It is a call chain only.

Format:
```
> `<Contract.entryFunction(params)>`
>   → `<calledFunction()>`
>     → `<deeperFunction()>` → **<outcome>**
```

Multiple entry points converging on one path use ` / ` on the first line:
```
> `<ContractA.entry()>` / `<ContractB.entry()>`
>   → `<sharedFunction()>`
>     → `<vulnerableOp()>` → **<outcome>**
```

**For Low/Informational findings**: The blockquote can describe the code path to the concern rather than a full attack chain.

### 3c — The metadata line

Format: `` `ContractName.functionName` · guard: **Y** ``

- `ContractName.functionName` is the primary vulnerable location, in a backtick span
- `guard:` is either **none** (if unprotected) or the name of the guard that exists but is bypassed or insufficient: **nonReentrant**, **onlyOwner**, **whenNotPaused**

### 3d — Precondition

Format: `**Precondition** — <text>`

Describe the minimum conditions the attacker must satisfy. Be specific and concrete.

- Good: `holds ≥1 LP token; pool is not paused`
- Good: `any EOA caller; no minimum deposit enforced`
- Bad: `attacker has access`, `some tokens`

**For Informational findings**: Use `**Precondition** — none (code concern)` or describe the condition under which the concern manifests.

### 3e — Impact

Format: `**Impact** — <text>`

Describe what is concretely lost or broken. Quantify where possible.

- Good: `all depositor funds drained from the pool; protocol insolvent`
- Good: `attacker extracts 2× deposited amount; other LPs share the loss pro-rata`
- Bad: `funds lost`, `bad things happen`

### 3f — Description

Format: `**Description** — <one sentence>`

Structure: what the code does wrong → how the attacker exploits it → what they gain.

- Use backticks for all function names, variable names, and Solidity types
- Do not repeat the attack path — add the mechanism detail instead
- Do not start with "This finding", "There is a", or "The contract"

Good: `` **Description** — `withdraw` uses `balanceOf(address(this))` instead of internal accounting; a flash-loan deposit inflates the balance, allowing the caller to extract more than their share. ``
Bad:  `**Description** — The withdraw function has a vulnerability that allows attackers to steal funds.`

### 3f+ — Assumptions (Critical / High / Medium only)

Format: `**Assumptions** — <text>`

State conditions not fully verified, and what validation would confirm or disprove.

- Good: `assumes token whitelist includes fee-on-transfer tokens; not verified whether admin restricts token list. Manual review of deployment config would confirm.`
- Good: `requires oracle staleness > 1 hour; Chainlink heartbeat for this pair not checked. Verify heartbeat interval for the specific price feed.`
- Bad: `some assumptions exist`

**Omit for Low/Informational/Design Advisory findings.**

### 3f++ — Design Intent (Design Advisory only)

Format: `**Design Intent** — <quote or citation from code NatSpec/comments>`

For Design Advisory findings, replace the Assumptions field with a Design Intent field that cites the documented design decision. Quote the relevant NatSpec, comment, or naming convention that confirms the behavior is intentional.

**Omit for all other severity levels.** Design Advisory findings also omit the diff block (same as Low/Informational).

### 3g — The diff block (Critical / High / Medium only)

Rules:
- Show real code from the contract, not pseudocode.
- The `-` lines must match the actual source exactly (or be a faithful excerpt).
- The `+` lines are the minimal fix — do not refactor surrounding code.
- Add a `// comment` on the `+` line only when the reason is non-obvious.
- **Omit the diff block entirely for Low/Design Advisory/Informational findings.** No fix section, no placeholder.

---

## Section 4 — Full Example

**IMPORTANT: The example below is a formatting template only. Do NOT treat these as real findings or reproduce them in your output. Your findings must come exclusively from analyzing the actual source code.**

~~~~markdown
# 🔐 contract-auditor — <ProjectName>

`<File>.sol` · <mode> · <YYYY-MM-DD>

| # | Severity | Title |
|---|----------|-------|
| 1 | High     | <finding title> |
| 2 | Medium   | <finding title> |
| 3 | Low      | <finding title> |
| 4 | Info     | <finding title> |

### Coverage

| Contract | Functions Analyzed | Analysis |
|----------|-------------------|----------|
| <Contract.sol> | N / M | <agent and call paths> |

---

## [High] 1. <Finding Title>

> `<Contract.entryFunction(params)>`
>   → `<calledFunction()>`
>     → `<vulnerableOp()>` → **<outcome>**

`<Contract.function>` · guard: **<none or guard name>**

**Precondition** — <specific conditions the attacker must satisfy>

**Impact** — <concrete loss or breakage, quantified where possible>

**Description** — <one sentence: what the code does wrong, how it is exploited, what is gained>

**Assumptions** — <conditions assumed but not verified; what validation would confirm>

```diff
- <vulnerable line from actual source>
+ <minimal fix>  // brief reason
```

---
~~~~
