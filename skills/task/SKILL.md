---
description: Pick up a task and drive it through the devflow cycle — from a local ticket file produced by /devflow:map, a tracker issue key (e.g. ABC-12), or a plain-text description. Use when asked to take, work on, or implement a task.
---

# Task: $ARGUMENTS

Read `.devflow/project.yml` → `tracker`, `maps`. No manifest → stop: the project isn't onboarded, point to `/devflow:init`.

## Resolve the task source

- **A path to a ticket file** (typically `<maps.dir>/<effort>/tickets/NN-slug.md`) → read it, and read the sibling `design.md` and `spec.md` for the sections it names. This is the primary path: the thinking is already done and recorded, so **do not re-plan it**. Check `Blocked by` — every ticket listed there must be `done` before this one starts; if not, say which one blocks and stop. Set `Status: in progress` before touching code: it is what the stop gate reads to tell an unfinished iteration from an ordinary session, and what tells the next session where a dead one stopped.
- **An issue key** (`ABC-123`) with `tracker.system` set → fetch the issue (MCP tools preferred, REST fallback). Extract: title, description, acceptance criteria, priority, linked issues. A local ticket carrying that key in its `Tracker:` line is the fuller source — prefer it.
- **Plain text** → this task was never designed, so the picture lives only in the user's head. Say so once and offer `/devflow:map <goal>` — it carries the idea through detailed design and comes back with tickets. If the user would rather go straight ahead, do: their call, and record it in the close-the-loop report as work done without a design pass. Projects without a tracker are a fully supported mode, not an error — never nag the user to configure one.
- Issue key given but no tracker configured → say so and ask for a ticket path or a description instead.

## Setup — before touching code

- **With tracker, ask whether to move the issue onto the board** (sprint / "in progress") — MANDATORY question, never skip: tasks must not be silently worked from the backlog. Apply the user's answer; first time, record the in-progress status name in the manifest as `tracker.wip_status`.
- **Branch from fresh base** per the manifest `git` section: `git checkout <base_branch> && git pull`, then create `branch_pattern` (e.g. `feature/ABC-12`; without a tracker key use a kebab-case slug — for a map ticket, the ticket's own slug). Never work directly on the base branch. If the working tree is dirty, stop and ask.
- **Commits** follow `git.commit_pattern`, e.g. `ABC-12: feat: add user search` (conventional-commit types: feat/fix/refactor/docs/test/chore).

## Drive the cycle

1. **Understand first**: explore how the affected flow works NOW, restate the task (current behavior → desired behavior → open questions). If the source contradicts the code you find, surface it before writing anything. **From a map ticket this is mostly done** — the map's *How it works today* holds the recon and `design.md` holds the interfaces, data shapes, and edge behavior; read them instead of re-deriving, and only verify what the code may have moved since.
2. **Implement against what was decided.** A map ticket brings its own acceptance checklist and design sections — implement those, and treat a gap in them as a question for the user, never as license to decide. Without a map: plan → user approval → implement.
3. **Verify** the acceptance criteria live, via `/devflow:test-flow` or `test.run`.
4. **A task too big for one commit** means it was never sliced: stop and offer `/devflow:map` rather than growing the diff.
5. **Code review — before the commit gate**: run the built-in `code-review` skill on the task's diff (default effort; `high` for risky/large changes). The built-in skill picks up the project's `REVIEW.md` (repo root) and CLAUDE.md on its own; treat REVIEW.md rules as part of your triage rubric too — its skip rules and severity definitions outrank generic taste. Triage findings: fix real issues now; include the rest in the close-the-loop presentation so the user decides (fix / commit anyway / file a follow-up via the issue skill). Skip only for trivial diffs (docs or one-line config). Warnings count as findings — the diff must build warning-clean.
6. **Knowledge sync — mandatory before closing**: review the task's diff and update every knowledge artifact it invalidated:
   - docs mapped in `docs.map` (definition-of-done);
   - **Confluence**: a touched flow whose `docs.map` entry carries a `confluence` page → propose the page update alongside the file edit: show the draft (what changes and why), apply via the Atlassian MCP **only on approval** — outward-facing, same protocol as tracker actions, never silent. Stamp the update with the commit/branch reference. MCP tools unavailable → say so, list the needed edits for manual transfer; never report the sync as done with the page silently skipped;
   - `.devflow/project.yml` — ports, services, env, auth, health, notes;
   - project CLAUDE.md — only if a *pattern* changed, not for feature details.
   Large diffs: delegate to the `docs-sync` agent scoped to the changed files. Stale knowledge taxes every future agent — you still hold the change context, so fixing it now is the cheapest it will ever be.
7. **Close the loop — gated by the user**:
   - Present the work as a **review handoff** — format per `${CLAUDE_SKILL_DIR}/../handoff/SKILL.md` (risk-ranked attention map: judgment calls and auto-red changes first, mechanical changes as a count, two-minute re-checks with the outputs you actually observed) — plus the proposed commit message. **Ask before committing** — never commit on your own initiative.
   - After the approved commit, finish per `git.on_done`: `push` → `git push -u origin <branch>` and report the branch name; `none` → leave everything local. **Never create PRs/merge requests** unless explicitly asked — the user handles those.
   - With tracker, after the commit: propose the issue comment + target status and **ask before posting or moving**. The closing comment must carry the outcome — what was done/decided, verification evidence, commit/branch reference; a bare status transition is not a closed task (the tracker is the team's memory, this chat is not). For research/decision tasks the comment IS the deliverable. First time, ask which status means "done for dev" and record it in the manifest as `tracker.done_status`.
   - **From a map ticket**: after the approved commit, tick its acceptance checklist and set `Status: done` in the ticket file. The ticket is the loop's memory — an implemented ticket still marked open makes the next session redo it. Then name the tickets the finished one just unblocked.
   - Without tracker: final report, and name the tickets this one unblocked.

## Rules

- Acceptance criteria — from the map ticket's checklist or the tracker issue — are the verification contract: **execute them live**. A clean build is compilation, not verification; a task must never reach "done" on build success alone.
- Never change issue status or post comments without the work actually verified.
- Commits, issue comments, and status transitions all require explicit user approval in this skill (`/devflow:build` in a /loop is the autonomous mode; this skill is the interactive one).
