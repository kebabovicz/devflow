---
description: Onboard the current project into devflow — explore the repo, generate .devflow/project.yml, suggest permissions, and plan project-specific gaps (dev auth, seed data). Use when setting up devflow in a new project.
disable-model-invocation: true
---

# devflow init

**Already onboarded? — do not re-init.** If `.devflow/project.yml` exists, first check for `.devflow/INIT.md`:
- **INIT.md exists** → this is an *unfinished* init, not a configured project. Resume from the first unchecked step in INIT.md — do not start over, do not overwrite what earlier steps already produced.
- **No INIT.md** → STOP: a second init would overwrite knowledge earned through real use (verified auth recipes, recorded statuses, notes). Say the project is already onboarded and offer the useful alternatives instead: `/devflow:doctor` (verify the init is healthy), `/devflow:config` (review current settings), `/devflow:update` (migrate the manifest after a plugin update). Proceed with re-init only if the user explicitly insists after this warning.

## Progress tracking — init must not die halfway

Init is long (7 steps + Tier 2 + validation) and conversations drift. An abandoned init is the most common way a project ends up half-configured, so progress lives in a file, not in the conversation:

- **First action** (right after the re-init check): write `.devflow/INIT.md` — a flat checklist of the steps below (Tier 1 items 1–7, Tier 2 if gaps were found, live validation), `- [ ]` each. Check items off as they complete.
- **Delete `.devflow/INIT.md` only at the end**: live validation passed, or the user explicitly deferred it and every unvalidated field carries `# UNVERIFIED`. While the file exists, init is not done — a SessionStart hook will remind about it in every new session.
- **If the user diverts mid-init** (a question, a quick fix, anything): help them, then steer back to the first unchecked item. Never silently abandon the checklist — if the user wants to stop for real, say plainly that init is unfinished, that INIT.md keeps the place, and that `/devflow:init` resumes from it.

Onboard the current repository into devflow. Two tiers of generation — never mix them up:

## Tier 1 — deterministic (generate directly)

1. **Detect the project type first** — devflow serves any repo, not just backends. Classify before exploring: backend service(s) / frontend app / mobile app / library or CLI / infrastructure-as-code / monorepo mix. Then explore what matters FOR THAT TYPE:
   - *backend*: compose files, how services start, API schemas (swagger/openapi), health endpoints, DB;
   - *frontend*: dev-server command, build, unit/e2e runners (vitest/playwright/cypress), which API it talks to (→ related_repos candidate), mocks;
   - *mobile*: build schemes/flavors, simulator/emulator workflow, test runner, backend dependency;
   - *library/CLI*: build, test, lint, example/demo entry points;
   - *infra-as-code*: validate/plan commands (terraform plan, ansible --check), state policy, target environments;
   - *monorepo mix*: identify the packages/areas first (workspaces, nx/turbo/melos config, solution files, top-level dirs), then explore each area per its own type from this list. ONE manifest at the repo root — never one per package: `env.up` is the whole-stack command (compose, turbo dev), `services` lists every HTTP surface across packages, `test.run` is the aggregate with per-package commands recorded in comments. If areas are so independent they share nothing (separate envs, separate release cycles), say so and suggest onboarding the busiest area's subdirectory as its own devflow project instead.
   Plus, for every type: how tests run, existing docs structure, hints of related repos.
2. **Interview the user** — preferences cannot be derived from code, so ask (one batch of questions, not a drip):
   - **Tracker**: Jira/GitHub/Linear or none? If yes: url, project key, issue language, area labels for created issues (e.g. BACKEND / FRONTEND / DEVOPS — whatever the team uses to route issues). "None" is a normal answer, not a gap. If Jira: also ask whether flow documentation lives in Confluence — if yes, record `docs.confluence` (site, space) and note that pages get mapped per flow in `docs.map` (here in step 8, or later via `/devflow:sync-docs`).
   - **Protected surface**: does exercising the project (or the API it fronts) require authentication? Exploration usually answers this — confirm the finding rather than ask open-ended. "No" is recorded as the `# none` marker (step 4), never as bare emptiness; "yes" with no headless path → a Tier 2 gap.
   - **Git flow**: base branch, branch naming (`feature/{key}`?), commit message format, what happens when a task is done (push / keep local). Check `git log` first and propose what the history already follows — confirm rather than ask open-ended (a young repo with no usable history → ask openly, proposing sensible defaults).
   - **Data policy** — only if the project has local data stores: disposable or persistent test state?
   - **Footprint**: commit devflow files into the repo (default — teammates get the manifest and settings; decision maps stay local either way) or keep devflow invisible in git (`footprint: local`)? Some users prefer not to advertise agent-assisted work — that is a legitimate choice, offer it neutrally.
   - Anything the repo exploration left ambiguous (e.g. two compose files, two test suites).
   Skip questions that don't apply to the detected type — an irrelevant question costs trust.
3. **Validate every answer before accepting it** — protect the manifest from values that are wrong or that devflow cannot honor:
   - enums: `project.type` ∈ backend/frontend/mobile/library/infra/mixed, `tracker.system` ∈ jira/github/linear (or none), `relationship` ∈ consumer/provider/sibling, `git.on_done` ∈ push/none. Anything else (Trello, auto-merge, deploy-on-done…) → say plainly it's not supported, name the closest supported option, leave the field empty. Never write a value devflow can't execute;
   - reality checks: `base_branch` must exist in the repo; `related_repos` paths must exist on disk; `branch_pattern` must contain `{key}` (or a slug placeholder), `commit_pattern` must contain `{subject}`; tracker url must answer (a HEAD request suffices);
   - **machine-specific values split**: for `related_repos`, identity (`url`, `branch`, `relationship`) goes into the committed manifest; the absolute local `path` goes into `.devflow/project.local.yml` (same key, sparse overlay, local wins) with a `.gitignore` entry for it — or `.git/info/exclude` when `footprint: local` (there a committed `.gitignore` line would betray the setup; everything under `.devflow/` is excluded that way already). A teammate's clone must not inherit this machine's filesystem layout. Solo projects may keep `path` in the manifest if the user prefers;
   - **the split applies to EVERY committed field, not just `related_repos`**: command fields (`env.*`, `test.*`, `db.*`, `auth.*`) and the `.claude/settings.json` allowlist must not embed absolute home paths (`/Users/…`, `/home/…`, `C:\Users\…`), `$HOME`, the local username, or a personal email — those are machine/person truth and go to the overlay (or `settings.local.json` for permissions). Prefer repo-relative commands (`./scripts/seed.sh`, not `/Users/x/project/scripts/seed.sh`). Doctor's machine-truth scan checks exactly this — write files that pass it;
   - **the ignore entry for `.devflow/project.local.yml` is created unconditionally** (in `.gitignore`, or `.git/info/exclude` for `footprint: local`) — even when nothing goes into the overlay today. The template promises the overlay is never committed; a value added next month must not depend on someone remembering the entry;
   - **`maps.dir` goes into `.git/info/exclude` unconditionally too — at every footprint, `committed` included.** Decision maps are the author's thinking, not team documentation, and the exclude entry must exist before the first map is written. It never goes into `.gitignore`: that file is committed, so the line itself would advertise the private draft. The same reason `footprint: local` uses `.git/info/exclude` — here it applies regardless of footprint;
   - command-like fields (env, test, db) are claims until the live-validation step runs them — they cannot fail init, but they cannot be hand-waved either.
4. **Draft `.devflow/project.yml`** from the template at `${CLAUDE_SKILL_DIR}/../../templates/project.yml` (two levels up from this skill's directory = the plugin root) — a draft: the file is written to disk only after the settings review in step 5. Fill every field you can derive from the repo or the interview. Leave the rest empty with a `# TODO` comment — never invent values. Confirmed absence beats ambiguous emptiness: when exploration + interview establish the project has NO protected surface, write `recipe: ""  # none — no protected surface` — config, doctor, and test-flow read this marker; a bare `""` means the question was never settled.
5. **Settings review — show, then write**: present the drafted configuration as a readable table (field → value → origin: derived from repo / your answer / default / TODO), ask what to adjust, and only then write the manifest to disk. Defaults are proposals, not decisions — this is the moment the user reshapes devflow to their taste, not after the fact. Re-validate adjustments per step 3. Close with: "later: view with `/devflow:config`, change by editing `.devflow/project.yml` or just asking".
6. **Suggest permissions**: propose an allowlist for `.claude/settings.json` matching the stack (build/test commands, docker compose, curl to localhost, db client). Show the diff, apply on approval. **Never allowlist outward-facing tracker or Confluence mutations** (issue create/edit/transition/comment/link, page create/update MCP tools): the permission prompt is the deterministic floor under the "show the draft, ask first" protocol — skills are advisory and long sessions drift past them, but an un-allowlisted tool call always stops and shows its full payload. Warn the user that answering "always allow" on those prompts removes that floor.
7. **CLAUDE.md section**: append (or propose) a short "devflow" section — where the manifest lives, definition-of-done rule: *changed a flow → update the mapped doc in the same change*. If the project has no CLAUDE.md at all, create a minimal one containing ONLY the devflow section, and recommend the built-in `/init` to author the rest — devflow *consumes* project rules (review rubric, coding patterns); it does not author them. Same layer, review rules: if a `REVIEW.md` exists at the repo root, note that both the built-in code-review and devflow's review skills honor it; if the team wants custom review rules (severity, skip paths, repo-specific checks), REVIEW.md is the canonical place — mention it, don't author it.
8. **Docs map**: propose `docs.map` entries from the docs found in step 1 — only git-tracked flow contracts qualify (untracked/gitignored files are personal notes: point them out, don't map them). No usable docs → mention that `/devflow:sync-docs` has an author mode that generates a canonical set from code — architecture, environments, testing, never an API-surface document; don't block init on it.

### `footprint: local` — leave no traces in git

When the user chose local-only: add `.devflow/`, `.claude/`, and (if a devflow section would have gone there) `CLAUDE.md` to **`.git/info/exclude`** — NEVER to `.gitignore`: `.gitignore` is itself committed and would betray the setup. `.git/info/exclude` is per-clone and invisible to the remote. Skip the CLAUDE.md append (put the definition-of-done note into the manifest instead); permissions still go to `.claude/settings.json` (now excluded). Spell out the trade-off once: the manifest lives on this machine only — back it up yourself; teammates won't inherit the setup.

## Tier 2 — agentic (plan → approval → implement)

Identify gaps that require **changes to project code** and treat each as a normal task with a plan the user reviews first. What counts as a gap depends on the project type — the constant is: *agents must be able to exercise the project end-to-end without a human in the loop*:

- **Headless access to the protected surface** (backend/frontend/mobile): a way to authenticate without a human — fixed OTP in Development, seed user, test token endpoint. Any bypass MUST be guarded: fail hard if environment != Development.
- **Seed/fixture data**: minimal dataset so flows are testable from a clean environment (backend: DB seed; frontend: mocks or a seeded dev API; library: example fixtures).
- **Missing exercise loop**: whatever prevents "change → run → observe" — services absent from local compose, missing health endpoints, a frontend with no dev-server/e2e setup, an IaC repo with no plan/validate wiring.

NEVER implement Tier 2 silently. Present the plan, wait for approval, implement, then verify by actually obtaining a token / starting the env.

**Deferred gaps must survive init**: if the user postpones a Tier-2 plan ("not now"), record each gap before finishing — as a ticket in a `setup` effort under `maps.dir` (one line: the gap + the planned fix), or as a tracker issue when one is configured. INIT.md dies at the end of init — a gap plan that lived only there is lost, which is exactly the knowledge loss the progress file exists to prevent.

## Finish — mandatory live validation

A manifest nobody has executed is a hypothesis, not a manifest. Before reporting success, actually run **every command-like field you filled**: `env.up` → health green (or dev server reachable, or `terraform validate` passes — whatever the type's exercise loop is); `auth.recipe` executed and a real token obtained (only if the auth section applies); `test.run` runs. Empty optional sections validate as nothing — they are configuration, not gaps. If the user defers validation, mark every unvalidated field with `# UNVERIFIED` in the manifest — and `# UNVERIFIED` covers every claim not proven live, not just commands: health URLs, service ports inferred from framework defaults, anything the repo text doesn't literally state. Auth recipes that cross async boundaries (queues, outbox) must include retry/polling, not assume instant delivery.

When validation passed (or was explicitly deferred with `# UNVERIFIED` markers in place): **delete `.devflow/INIT.md`** — init is complete only once the progress file is gone — and report the final state, listing any UNVERIFIED fields as the user's homework.
