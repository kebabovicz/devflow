---
description: Show the current devflow configuration of this project in a readable form — env, auth, tests, git conventions, tracker, related repos, data policy. Read-only. Use when asked how devflow is set up here, what conventions apply, or to review settings without digging through files.
---

# devflow config

Read-only view of how devflow is configured for this project. Source of truth: `.devflow/project.yml`, plus `.devflow/project.local.yml` overlaid if present (machine-local values — win over the manifest; mark them `(local)` in the output). No manifest → say the project isn't onboarded and point to `/devflow:init`; do not invent a configuration.

## Output — grouped, human-readable, no YAML dumps

Render the manifest as compact sections (skip empty sections silently; a project without a tracker is configured, not broken):

- **Project**: name, stack, type (backend/frontend/mobile/library/infra/mixed), footprint (committed / local — with one line on what that means).
- **Environment**: how it starts/stops, health checks, services and their ports.
- **Auth**: the recipe in one line (steps, not commands) + its verification status **read from the manifest's markers**: a field carrying `# UNVERIFIED` → UNVERIFIED, otherwise VERIFIED (init validates live before writing). A `# none` marker → render "none — no protected surface (confirmed)"; empty with NO marker → "not configured (never asked or deferred)" — don't skip the section silently in either of these cases. Never invent a status from session state — "not run in this session" is not UNVERIFIED.
- **Tests**: unit/integration commands.
- **Data policy**: persistent or disposable; snapshot/restore if configured.
- **Git conventions**: base branch, branch pattern, commit pattern, what happens on done.
- **Tracker**: system, project, language, labels, board statuses (wip/done if recorded).
- **Related repos**: name → path, branch, relationship.
- **Ralph**: TODO path + its state (n unchecked / m done / blocked items), specs dir.
- **Docs map**: flow → doc file pairs.

Close with a status line:
- plugin version (from `${CLAUDE_SKILL_DIR}/../../.claude-plugin/plugin.json` — two levels up = the plugin root);
- if `.devflow/INIT.md` exists — say first: **init is unfinished** (n steps remain), resume with `/devflow:init`;
- count of `# TODO` / `UNVERIFIED` markers in the manifest, listed if any — each is a setting nobody confirmed yet;
- missing template sections → suggest `/devflow:update`; suspected misconfiguration → suggest `/devflow:doctor`.

## Rules

- Strictly read-only: no edits, no fixes, no environment calls. To change a setting the user edits the manifest or just asks — re-validate changed values by the same rules init uses (enums, placeholders, paths/branches exist) before writing.
- Never print secrets even if someone put one in the manifest — mask it and flag it as a finding (credentials never belong in the committed manifest).
