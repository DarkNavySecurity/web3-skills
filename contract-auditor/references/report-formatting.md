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
`File1.sol` · `File2.sol` · <mode> · <YYYY-MM-DD> · threshold <N>
```

- List every in-scope file as a backtick span, separated by ` · `
- `<mode>` is one of: `default` / `DEEP` / `filename`
- `<YYYY-MM-DD>` is today's date
- `<N>` is the confidence threshold (default 60)

---

## Section 2 — Findings Summary Table

Immediately after the header line, before any findings:

```
| # | Score | Title |
|---|-------|-------|
| 1 | [100] | Title of finding 1 |
| 2 | [85]  | Title of finding 2 |
|   |  ·    |                   |
| 3 | [75]  | Title of finding 3 |
| 4 | [60]  | Title of finding 4 |
```

Rules:
- Sort by confidence descending.
- The `·` row is the only separator between above-threshold and below-threshold findings.
- Scores in brackets: `[100]`, `[85]`, `[75]`.
- Titles must match the `##` heading titles exactly.

Then `---` before the findings section.

---

## Section 3 — Findings

Each finding follows this exact structure, separated by `---`:

```
## [score] N. Title of Finding

> `entryFunction(params)` → `calledFunction` → `vulnerableOperation` → **outcome**

`ContractName.functionName` · guard: **none**

**Precondition** — <what the attacker must control or satisfy>

**Impact** — <what is lost or broken if exploited>

**Description** — <one sentence: what the code does wrong and how it is exploited>

```diff
- the vulnerable line or lines
+ the fixed line or lines  // brief reason why this fixes it
```

---
```

### 3a — The `##` heading

Format: `## [score] N. Title`

- `[score]` is the confidence number in brackets: `[100]`, `[85]`, `[75]`
- `N` is the sequential finding number
- Title is concise (≤10 words), describes the root cause not the symptom

Good: `## [95] 1. Unchecked Return Value Enables Double Withdrawal`
Bad:  `## [95] 1. Missing Input Validation in withdraw Function`

### 3b — The attack path blockquote

Format: `> backtick-chain → backtick-chain → ... → **plain outcome**`

Rules:
- Every function name and variable is wrapped in backticks: `` `withdraw(amount)` ``
- Arrows are ` → ` (space, right arrow, space)
- The final outcome is **bold plain text**, not a function name: → **drain pool**
- Keep to one `>` line where possible. If the chain is long, break into two `>` lines.
- Do not write prose in the blockquote. It is a call chain only.

Good: `` > `deposit(token, amt)` → `_updateBalance` → `withdraw(amt+1)` → **drain reserve** ``
Bad:  `> The attacker calls deposit and then withdraws more than they put in`

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

### 3g — The diff block (above-threshold findings only)

Rules:
- Show real code from the contract, not pseudocode.
- The `-` lines must match the actual source exactly (or be a faithful excerpt).
- The `+` lines are the minimal fix — do not refactor surrounding code.
- Add a `// comment` on the `+` line only when the reason is non-obvious.
- **Omit the diff block entirely for below-threshold findings.** No fix section, no placeholder.

---

## Section 4 — Full Example

**IMPORTANT: The example below is a formatting template only. Do NOT treat these as real findings or reproduce them in your output. Your findings must come exclusively from analyzing the actual source code.**

```
# 🔐 contract-auditor — <ProjectName>

`<File>.sol` · <mode> · <YYYY-MM-DD> · threshold <N>

| # | Score | Title |
|---|-------|-------|
| 1 | [score] | <finding title> |
| 2 | [score] | <finding title> |
|   |  ·      |                 |
| 3 | [score] | <below-threshold finding title> |

---

## [score] 1. <Finding Title>

> `<entryFunction(params)>` → `<calledFunction>` → `<vulnerableOp>` → **<outcome>**

`<Contract.function>` · guard: **<none or guard name>**

**Precondition** — <specific conditions the attacker must satisfy>

**Impact** — <concrete loss or breakage, quantified where possible>

**Description** — <one sentence: what the code does wrong, how it is exploited, what is gained>

```diff
- <vulnerable line from actual source>
+ <minimal fix>  // brief reason
```

---
```
