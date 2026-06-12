---
description: Pick up a task and drive it through the devflow cycle — from a tracker issue key (e.g. ABC-12) or a plain-text description. Fetches the issue when a tracker is configured. Use when asked to take, work on, or implement a task.
---

# Task: $ARGUMENTS

Read `.devflow/project.yml` → `tracker`. No manifest → stop: the project isn't onboarded, point to `/devflow:init`.

## Resolve the task source

- "$ARGUMENTS" looks like an issue key (`ABC-123`) and `tracker.system` is set → fetch the issue (MCP tools preferred, REST fallback). Extract: title, description, acceptance criteria, priority, linked issues.
- `tracker.system` is empty, or the argument is plain text → "$ARGUMENTS" **is** the task description. Projects without a tracker are a fully supported mode, not an error — never nag the user to configure one.
- Issue key given but no tracker configured → say so and ask for the task description instead.

## Setup — before touching code

- **With tracker, ask whether to move the issue onto the board** (sprint / "in progress") — MANDATORY question, never skip: tasks must not be silently worked from the backlog. Apply the user's answer; first time, record the in-progress status name in the manifest as `tracker.wip_status`.
- **Branch from fresh base** per the manifest `git` section: `git checkout <base_branch> && git pull`, then create `branch_pattern` (e.g. `feature/ABC-12`; without a tracker key use a kebab-case slug). Never work directly on the base branch. If the working tree is dirty, stop and ask.
- **Commits** follow `git.commit_pattern`, e.g. `ABC-12: feat: add user search` (conventional-commit types: feat/fix/refactor/docs/test/chore).

## Drive the cycle

1. **Understand first**: explore how the affected flow works NOW, restate the task (current behavior → desired behavior → open questions). If the issue contradicts the code you find, surface it before writing anything.
2. **Small task** (one-commit blast radius) → plan → user approval → implement → verify (acceptance criteria via `/devflow:test-flow` or `test.run`).
3. **Large task** → hand off to `/devflow:ralph-plan` with a spec referencing the issue key, then `ralph-build` iterations.
4. **Code review — before the commit gate**: run the built-in `code-review` skill on the task's diff (default effort; `high` for risky/large changes). Triage findings: fix real issues now; include the rest in the close-the-loop presentation so the user decides (fix / commit anyway / file a follow-up via the issue skill). Skip only for trivial diffs (docs or one-line config). Warnings count as findings — the diff must build warning-clean.
5. **Knowledge sync — mandatory before closing**: review the task's diff and update every knowledge artifact it invalidated:
   - docs mapped in `docs.map` (definition-of-done);
   - `.devflow/project.yml` — ports, services, env, auth, health, notes;
   - project CLAUDE.md — only if a *pattern* changed, not for feature details.
   Large diffs: delegate to the `docs-sync` agent scoped to the changed files. Stale knowledge taxes every future agent — you still hold the change context, so fixing it now is the cheapest it will ever be.
6. **Close the loop — gated by the user**:
   - Present the work as a **review handoff** — format per `${CLAUDE_SKILL_DIR}/../handoff/SKILL.md` (risk-ranked attention map: judgment calls and auto-red changes first, mechanical changes as a count, two-minute re-checks with the outputs you actually observed) — plus the proposed commit message. **Ask before committing** — never commit on your own initiative.
   - After the approved commit, finish per `git.on_done`: `push` → `git push -u origin <branch>` and report the branch name; `none` → leave everything local. **Never create PRs/merge requests** unless explicitly asked — the user handles those.
   - With tracker, after the commit: propose the issue comment + target status and **ask before posting or moving**. The closing comment must carry the outcome — what was done/decided, verification evidence, commit/branch reference; a bare status transition is not a closed task (the tracker is the team's memory, this chat is not). For research/decision tasks the comment IS the deliverable. First time, ask which status means "done for dev" and record it in the manifest as `tracker.done_status`.
   - Without tracker: final report + check off the item in `ralph.todo` if it lives there.

## Rules

- Acceptance criteria from the issue are the verification contract — **execute them live**. A clean build is compilation, not verification; an issue must never reach "done" on build success alone.
- Never change issue status or post comments without the work actually verified.
- Commits, issue comments, and status transitions all require explicit user approval in this skill (ralph-build in a /loop is the autonomous mode; this skill is the interactive one).
