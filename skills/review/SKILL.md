---
description: Iterative code review LOOP along two independent checks — Standards (does the code follow this project's rules?) and Requirements (does the diff implement exactly what was decided?) — fix accepted findings, re-review until a pass comes back clean. Use when asked to polish a change "until 10/10" or review thoroughly/iteratively. For a single review pass, the built-in code-review skill is the right tool (this skill wraps it in a fix-and-re-review cycle). Add 'swarm' to run the review pass as a parallel multi-agent fan-out with adversarial verification of each finding.
---

# Review: $ARGUMENTS

**Read `${CLAUDE_SKILL_DIR}/../OUTPUT-STYLE.md` before your first message and follow it** — it binds every message this skill prints and every file it writes for a person to read.

Iterative review-fix-review loop. Scope from "$ARGUMENTS": a branch (diff vs `git.base_branch` from `.devflow/project.yml`), a PR number, or — default — uncommitted changes plus the current branch's commits over base. Works without a manifest too (generic review), but then say that project conventions could not be loaded.

This is the end-of-work review, run deliberately: by the user, or offered by another skill when a ticket closes. `/devflow:task` does **not** call it — a task carries its own single check and its own triage, and nesting one gated loop inside another buys nothing.

## Two checks, side by side

Every pass judges the diff along two axes that answer different questions:

- **Standards** — is the code written the way this project writes code?
- **Requirements** — does the diff implement exactly what was decided before it was written?

A change can pass one and fail the other: code that honours every convention while building the wrong thing, or code that does precisely what was asked in a style the project rejects. **The two are never merged and never reranked against each other** — the moment they are, the louder axis hides the quieter one, and the quiet one is usually Requirements.

They also run **independently, so neither colours the other**: the Requirements check is a subagent with a clean context that is given the decisions and the diff and nothing else — it must not learn to see the code through a style reviewer's eyes; the Standards check runs here, as the built-in `code-review` skill, and is never told what Requirements found. Both are in flight before either report is read.

### Standards

1. Load the project's own rules first: **`REVIEW.md` at the repo root** (the file the built-in code-review reads as its highest-priority instruction block — severity definitions, skip rules, repo-specific checks), CLAUDE.md, and the style/security/testing docs they reference. Together they are the rubric. A "finding" that contradicts the project's documented style is not a finding; a violation of those documented rules is always one, even if generic taste would shrug. REVIEW.md skip rules apply to triage too — a finding in a skipped path/category is dropped, not presented.
2. On top of the project's rubric, always carry the smell baseline in `${CLAUDE_SKILL_DIR}/SMELLS.md` — pasted into the check whole, with the rules that bind it: every smell is a judgment call, a documented project rule turns it into one question rather than silencing it, "deliberate" is offered a line in `REVIEW.md` so it survives the session, and anything tooling enforces is skipped.
3. Warnings count as findings — the diff must build warning-clean (per the project's analyzer config).

### Requirements

The source is whatever recorded the decisions, taken in this order — stop at the first that exists:

1. **The map ticket** the work implements (`<maps.dir>/<effort>/tickets/NN-slug.md`) plus the `design.md` sections it names, and the effort's `spec.md` *Out of scope* — the cheapest possible answer to "was this asked for?". Several tickets in scope → report per ticket, keeping them separate.
2. **A tracker key** in the commit messages → fetch the issue per the manifest's `tracker` section.
3. **A path passed in "$ARGUMENTS"** — a spec file, a design doc.
4. Nothing found → **ask**. If the user says there is no spec, the check reports "nothing to compare against" in one line and the pass carries Standards alone. Silence here would read as a pass.

The check reports three classes, each quoting the line of the spec, design, or ticket it rests on:

- **missing or partial** — something the decisions require that the diff does not deliver;
- **unasked-for** — behavior in the diff that nothing required, including a change reaching past this ticket into a neighbour's territory;
- **wrong** — a requirement that looks implemented but whose implementation does not do what was decided.

## Reporting

Two headings, `## Standards` and `## Requirements`, each carrying its checker's report near-verbatim. Close with a single line: how many findings each check produced, and the worst finding **within each**. Never a winner across the two.

## Triage — the user decides, and the decision sticks

Standards findings are fixed in code, or accepted; an accepted judgment call is RESOLVED and must not reappear in a later pass. A smell the user calls deliberate is offered its line in `REVIEW.md` (see `SMELLS.md`).

A Requirements finding has three possible outcomes, and picking the right one matters more than the fix:

- **the code is wrong** → fix it now;
- **the decision was wrong** → the fix belongs in the design, not in this diff. **Write the question under *Open questions* in the ticket it concerns and stop there** — and find that ticket through the `Blocked by` graph rather than by its title. Do not rewrite the chain: a decision taken while implementing ticket 1 that touches ticket 2 will also reach ticket 3, which depends on 2 — and re-planning both from inside ticket 1 re-plans them without the information ticket 2 will have. Point the collision out when you see it, record it where it will be read, and let it be settled when that ticket comes up.
- **the departure was deliberate** → it gets one line in the ticket saying so. An unexplained departure is read as a slip by the next reviewer and "fixed" back.

## The loop

1. **Review pass**: both checks, as above.
2. **Triage with the user**: real defects and rule violations → fix now; judgment calls → present, the user decides (fix / accept / file via `/devflow:issue`).
3. **Fix** the accepted findings.
4. **Re-review**: both checks again — a fix aimed at Requirements can break Standards, and the reverse. The next pass covers the fixes plus anything they touched, and the rest of the scope at normal depth.
5. **Converged** when a full pass returns zero actionable findings on both checks — that's the 10/10. Report it plainly.

## Convergence rules (anti-churn — what makes "until 10/10" terminate)

- An empty pass is SUCCESS, not an invitation to look harder. Never invent nits to fill a pass.
- A finding that reverses a fix from an earlier pass → STOP and surface the contradiction; do not oscillate.
- Default cap: 3 passes. Not converged by then → the remaining findings are presented as a list with your honest assessment (real debt vs reviewer noise); the user decides whether to continue.
- Each pass must cite the rule, the decision, or the defect class behind every finding ("REVIEW.md says X", "design.md *Data shapes* says Y", "unhandled null"). "Could be nicer" without a citable basis doesn't survive triage.

## Swarm mode (`swarm` — heavy, multi-agent, opt-in)

`swarm` as a word in "$ARGUMENTS" turns the single-threaded loop into a parallel Workflow: the user typing it IS their opt-in to the expensive path — announce the plan (the review dimensions found, how many agents, that a swarm review runs on the order of 100–200k tokens) and proceed, don't re-ask for permission.

- **Only when the Workflow tool is available** in this session, and only when the scope is worth it — a handful of changed lines still reviews inline; a large or risky branch is what swarm is for. No Workflow tool → say so once and fall back to the normal loop above.
- **Shape**: Standards fans out into one finder per dimension the rubric implies (correctness, security, performance, every repo-specific check REVIEW.md defines, the smell baseline), each fed the project rubric; Requirements fans out into one finder per decision source in scope — a ticket with its design sections, an issue, a spec file. As each finder returns, its findings go to adversarial verifiers (skeptics prompted to REFUTE, defaulting to refuted when uncertain); a finding survives only on majority-confirm. REVIEW.md skip rules prune before verification, not after.
- **The two checks stay apart through the whole fan-out** — separate finders, separate verifiers, separate reports. Swarm multiplies the finders, it does not merge the axes.
- **Then rejoin the loop**: surviving findings enter the same triage → fix → re-review cycle and the convergence rules above — swarm replaces the *review* pass, not the human triage gate. On a large diff the fix and re-review passes may themselves run as a swarm.

## Model note

Review quality scales with the model. This skill follows the session model — for the "strongest model until clean" workflow, run it in your strongest available session (review subagents inherit it). Deep multi-agent cloud review of a whole branch is the built-in `/code-review ultra` (user-triggered, billed) — recommend it for large risky branches instead of looping this skill. That cloud `ultra` and this skill's local `swarm` are different tools: `ultra` runs in Anthropic's cloud and is billed per run; `swarm` fans out subagents inside your current session.
