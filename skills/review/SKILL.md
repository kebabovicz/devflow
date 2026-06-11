---
description: Iterative code review LOOP — judge the diff against the project's own rules, fix accepted findings, re-review until a pass comes back clean. Use when asked to polish a change "until 10/10" or review thoroughly/iteratively. For a single review pass, the built-in code-review skill is the right tool (this skill wraps it in a fix-and-re-review cycle).
---

# Review: $ARGUMENTS

Iterative review-fix-review loop. Scope from "$ARGUMENTS": a branch (diff vs `git.base_branch` from `.devflow/project.yml`), a PR number, or — default — uncommitted changes plus the current branch's commits over base. Works without a manifest too (generic review), but then say that project conventions could not be loaded.

## Criteria — the project's rules outrank generic taste

1. Load the project's own rules first: CLAUDE.md and the style/security/testing docs it references. They are the rubric. A "finding" that contradicts the project's documented style is not a finding; a violation of those documented rules is always one, even if generic taste would shrug.
2. Warnings count as findings — the diff must build warning-clean (per the project's analyzer config).

## The loop

1. **Review pass**: run the built-in `code-review` skill on the scope with high effort, feeding it the project rubric.
2. **Triage with the user**: real defects and rule violations → fix now; judgment calls → present, the user decides (fix / accept / file via `/devflow:issue`). An accepted judgment call is RESOLVED — it must not reappear in later passes.
3. **Fix** the accepted findings.
4. **Re-review**: next pass covers the fixes plus anything they touched, and the rest of the scope at normal depth.
5. **Converged** when a full pass returns zero actionable findings — that's the 10/10. Report it plainly.

## Convergence rules (anti-churn — what makes "until 10/10" terminate)

- An empty pass is SUCCESS, not an invitation to look harder. Never invent nits to fill a pass.
- A finding that reverses a fix from an earlier pass → STOP and surface the contradiction; do not oscillate.
- Default cap: 3 passes. Not converged by then → the remaining findings are presented as a list with your honest assessment (real debt vs reviewer noise); the user decides whether to continue.
- Each pass must cite the rule or defect class behind every finding ("CLAUDE.md says X", "unhandled null", …). "Could be nicer" without a citable basis doesn't survive triage.

## Model note

Review quality scales with the model. This skill follows the session model — for the "strongest model until clean" workflow, run it in your strongest available session (review subagents inherit it). Deep multi-agent cloud review of a whole branch is the built-in `/code-review ultra` (user-triggered, billed) — recommend it for large risky branches instead of looping this skill.
