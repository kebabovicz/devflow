---
description: Ralph BUILDING mode — pick the top task from the TODO, implement it, verify, commit, mark done. One task per iteration; designed to be driven by /loop. Use when executing a planned task list.
disable-model-invocation: true
---

# Ralph: BUILDING

Read `.devflow/project.yml`; the TODO lives at `ralph.todo`, specs at `ralph.specs_dir`. If the TODO is missing or empty → stop and say `/devflow:ralph-plan` is needed first.

**Branch check first**: you must be on a task branch, never `git.base_branch` (the guard will block commits there anyway). If the TODO names its branch, switch to it; if you're on the base branch, create one per `git.branch_pattern` (e.g. `feature/user-search-tests`) and record it at the top of the TODO.

**Clean-tree invariant**: `git status` must be clean before you pick a task. If it is dirty, a previous iteration died between work and commit — do NOT start new work. Match the leftover changes to their task (the TODO notes tell you which), finish THAT iteration's commit first, then proceed.

## One iteration = one task

1. **Pick** the topmost unchecked task. Read its spec. If the task is ambiguous or conflicts with the code you find — do NOT guess: write the question into the TODO under `## Blocked`, skip to the next task.
2. **Implement in a fresh context**: delegate implementation + verification to a subagent (Task tool, general-purpose) — give it the task text, its spec path, the manifest's `test` section, and the project conventions pointer (CLAUDE.md). The subagent implements following existing patterns (read sibling files first), runs the task's "done when" check, and reports: files changed, verification output, anything learned that the TODO should record. You stay the orchestrator — your context holds the loop's state, not the implementation noise; that is what keeps quality flat across a long run. The implementation subagent inherits the session model deliberately (it writes production code — never downgrade it to a cheaper model). Exception: trivial tasks (single small file, no test changes) may be done inline.
   - **Red/green when tests are the AC**: have the failing test written and seen red first, then implement until green — a test that has never failed proves nothing.
3. **Verify the subagent's claim yourself**: read the diff (`git diff`), check it against the spec, re-run the "done when" line / `test.run` from the manifest — the subagent's report is a claim, not a verification. Not green → fix (or send back) until green, or move the task to `## Blocked` with what you learned.
4. **Knowledge sync**: update docs mapped in `docs.map` if the task changed a documented flow (definition-of-done); same for `.devflow/project.yml` if it changed ports, services, env, auth, or health behavior.
5. **Mark done** in the TODO: check the task off **in place** (one-line result note). If the task involved a judgment call — a defensible alternative existed (locking strategy, API shape, error semantics, library choice) — the note MUST carry it: `⚠ judgment call: chose X over Y`. After a run the user greps the TODO for `⚠` to find every fork the loop took; an unrecorded fork is invisible forever. Never move tasks to another section — a single flat list is the loop's memory; duplicated Pending/Completed sections drift apart.
6. **Commit atomically**: the files this task touched **plus the TODO** in one commit (code and its checkmark are inseparable — that's what makes progress restorable from any machine). Message references the task. Never commit unrelated drive-by changes; if you fixed a pre-existing bug en route, that is a separate commit before this one. The iteration is NOT done until this commit exists — a green test with a dirty tree is a failed iteration.
   - `project.footprint: local` → commit the code only; the TODO is git-excluded by design (the user chose no devflow traces in git) and its checkmark lives outside version control. Never `git add -f` excluded devflow files.

## Loop discipline

- ONE task per invocation. Finishing early is success, not an invitation to start the next task — the loop will call you again.
- All `## Blocked` and nothing buildable → report the blockers and stop the loop instead of churning.
