# devflow — the guide

A Claude Code plugin that turns development into a managed process: you set tasks and make decisions; agents explore, implement, test, and keep the records. One plugin — many projects: everything project-specific lives in the `.devflow/project.yml` manifest; the plugin itself knows nothing about your project.

---

## Why

| Pain | How devflow addresses it |
|---|---|
| Testing the API by hand is slow | `/devflow:test-flow` — the agent brings up the environment, obtains a token, runs the scenario, returns an expected-vs-actual table |
| Findings from tests get lost in chat | `/devflow:issue` — a finding becomes a tracker issue (with evidence and a done-criterion) |
| Large tasks don't survive a session | The Ralph loop: plan and progress live in files (`.devflow/TODO.md`); sessions are disposable |
| Documentation rots | Knowledge sync: at the end of every task the agent updates docs/manifest against the diff |
| Moving your setup to a new project | `/devflow:init` — one-command onboarding |

A real example from the first day of production use: a flow test found that a service published events past the DB outbox → one command filed a tracker issue → during implementation the agent noticed the ticket contradicted the codebase and asked how to proceed → implementation → a re-run caught the outbox row live → the issue was closed with evidence.

## How it's built

```
The plugin (this repository)         Each project
├── skills/  — /devflow:* commands   ├── .devflow/project.yml  ← manifest: env, auth,
├── agents/  — subagents             │     ports, tests, docs, tracker
│   ├── api-tester  (tests flows)    ├── .devflow/TODO.md, specs/  ← Ralph state
│   └── docs-sync   (audits docs)    └── .claude/CLAUDE.md  ← project knowledge
└── templates/ — manifest template
```

**Guardrails (hooks)** — hard limits that work deterministically (the model cannot "forget" them; Claude Code itself enforces them): destroying docker volumes with data (`down -v`, `volume rm/prune`) and committing directly to the base branch. Active only in projects with a manifest; the escape hatch is a `DEVFLOW_ALLOW=1` prefix, which agents may use only when you explicitly asked for the blocked action. Scripts are fail-open: any error means allow — a broken guard never paralyzes sessions.

Principles:
- **The manifest is the single source of project specifics.** An agent reads the yml and knows how to start the environment, get a token, find the docs.
- **Progress lives in files, not in context** (Ralph-style). Any session can be killed — state survives.
- **Verification = executing the acceptance criteria live.** A clean build is compilation, not "done".
- **Outward actions need your confirmation**: commits, tracker issues, status transitions (autonomous `/loop` runs are the exception).
- **Subagents burn their own context**: heavy work happens in isolated windows; only the report comes back to your session.
- **Model choice follows the kind of thinking, not the importance**: mechanical agents (api-tester, docs-sync) are pinned to sonnet — saving your main model's rate limits; anything writing production code (the ralph-build implementation subagent, review) inherits the session model — no economizing there.

## Install (new person / new machine)

**Mode 1 — as a plugin (recommended):**
```bash
claude plugin marketplace add kebabovicz/devflow
claude plugin install devflow@devflow
```
Update: `claude plugin update devflow@devflow` (or `/plugin` in a session). The plugin registers normally — visible in `/plugin`; hooks and skills load from the install cache.

**Mode 2 — dev mode (for working on devflow itself):**
```bash
git clone https://github.com/kebabovicz/devflow ~/devflow && ~/devflow/install.sh
```
The script checks dependencies (claude, git, jq, docker), fixes hook exec bits, and symlinks into `~/.claude/skills/` — edits to the repo take effect immediately. Idempotent. Update: `git -C ~/devflow pull`.

> ⚠ One mode at a time: plugin + symlink together double-loads skills and hooks. After switching modes, start a new session (or `/reload-plugins`): the old hook registration keeps the previous path and produces noisy errors until reloaded. After any install, verify hooks for real: `/devflow:doctor` (registration test, not just the scripts).

Either mode: changes are listed in `CHANGELOG.md`; if the manifest template changed, run `/devflow:update` in your projects.

Jira (optional, once):
```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp -s user
```
then in a session: `/mcp` → atlassian → Authenticate (OAuth in the browser; no tokens are stored anywhere).

Onboarding a project: open a session in the project root → `/devflow:init`. It explores the repo, generates the manifest and permissions; gaps that require code (dev auth, seed data) are run as normal tasks with your approval.

## Command reference

| Command | What it does | When to use |
|---|---|---|
| `/devflow:init` | Project onboarding: explores the repo → interview (tracker, git conventions, data policy, footprint) → settings review → manifest + permissions + CLAUDE.md section → live validation | Once per project. Re-running is protected: init sees the manifest and offers doctor/config/update instead of overwriting |
| `/devflow:update` | Migrates the manifest to the current template: additive only, never overwrites | After a plugin update, if the manifest template changed |
| `/devflow:doctor [full]` | Diagnostics: dependencies, hook registration + script self-tests, manifest health, permissions; `full` adds live checks (env, auth recipe, tracker) | First command when "something's broken"; after install/update; on a new machine |
| `/devflow:config` | The project's current configuration, readable: env, auth, tests, git conventions, tracker, related repos + a list of unconfirmed settings | "How is this set up?" — without digging through yml. Read-only; change things by editing the manifest or just asking |
| `/devflow:test-flow <flow>` | Verifies a business flow against live services: starts the environment, authenticates, runs the scenario, reports expected vs actual | After API changes; checking "does it actually work"; verifying tasks |
| `/devflow:task <ABC-12 \| text>` | Full task cycle: understand → discuss → plan → implement → verify acceptance live → (asking first!) commit and close | The main work command. With a key it pulls from the tracker; with text it works without one |
| `/devflow:issue <finding>` | Drafts an issue per your conventions → your approval → files it in the tracker | When a test or discussion produced a finding that must not be lost |
| `/devflow:review [branch \| PR]` | Iterative review: a pass judged by the project's own rules → fix accepted findings → re-review, until a clean pass (max 3 rounds, anti-churn rules) | "Polish until 10/10". A branch after a Ralph run; for a large risky diff prefer `/code-review ultra` |
| `/devflow:research [quick] <question>` | Research with the methodology built in: primary sources > team experience > forums > SEO; a mandatory contrarian pass; triangulation; a digest with confidence grades and an honest "what remains unknown". Multi-angle digs fan out to subagents **behind a cost gate** (announced before spending, ~15 tool calls per subagent); `quick` = inline single pass, no subagents — cheap, every finding carries its (mostly weaker) confidence grade | Before choosing a technology/approach; "what's current practice"; collecting real-world experience including minority views. `quick` for low-stakes questions, never for irreversible decisions. Works outside devflow projects too |
| `/devflow:ralph-plan <goal>` | PLANNING: spec + gap analysis → a prioritized TODO in files | Before a large task (multiple commits, multiple sessions) |
| `/devflow:ralph-build` | BUILDING: one TODO task per iteration — implementation goes to a **fresh-context** subagent, the orchestrator re-verifies the diff and the "done when" itself, commits code+checkmark in one commit | Executing the plan. For an autonomous loop: `/loop /devflow:ralph-build` |
| `/devflow:sync <name>` | Diff of a related repo (from the manifest's `related_repos`) since the last sync → change classification → an adaptation plan | Any counterpart repository moved ahead: the frontend for a backend dev, the backend for a mobile dev, infra-as-code for either, a shared contracts repo for everyone; `relationship` (consumer/provider/sibling) in the manifest sets the direction. Single-repo projects simply never configure it |
| `/devflow:sync-docs` | Audits docs (+manifest, +CLAUDE.md) against the code, fixes what's stale. Full audits run as a parallel fan-out: 3–4 subagents by area + one aggregated digest; can run in the background | Periodically; after large merges made outside devflow |
| `/devflow:handoff [branch]` | Review handoff for a diff: risk-ranked attention map (judgment calls + auto-red changes → spot-check items → mechanical count) and two-minute re-checks with actually observed outputs. Honest limit: only the re-checks are falsifiable — the rest is the agent's self-assessment, a floor for attention, not proof | Your verification time is the bottleneck. Built into `/devflow:task` close-the-loop; standalone — for work done without devflow skills or by another agent |

Useful built-in Claude Code commands alongside devflow:

| Command | Why it pairs well |
|---|---|
| `/loop /devflow:ralph-build` | The autonomous closed loop: the agent grinds the TODO until done or blocked |
| `/code-review` | Built into the `/devflow:task` pipeline (the pre-commit step). Manually: on a whole branch after a `/loop` run; `/code-review ultra` — deep multi-agent cloud review for big features |
| `/clear` | Context hygiene: one task = one session |
| `/reload-plugins` | Pick up plugin changes without restarting the session |

## When NOT to use devflow (choose the entry by task size)

devflow is not a mode — it is a set of entry points. For small things the full pipeline is overkill, by design:

| Task | The right entry |
|---|---|
| A typo, a small refactor, something you can eyeball | just ask in the session — no skills, no ceremony |
| API behavior / contracts / shared areas change | `/devflow:task` — the full cycle (review, live acceptance, gates) |
| "How does this work now?", checking a hypothesis | a question, or `/devflow:test-flow` |
| Large, multi-session work | `/devflow:ralph-plan` → `ralph-build` |

Gates can be skipped deliberately ("no review, I'll look myself") — that's management, not a violation. devflow protects against skipping *by forgetfulness*, not against your decisions. Only the guardrails (irreversible actions) are always on — and they are invisible until you do something dangerous. The one step worth keeping even on small changes: if the edit touched a flow listed in `docs.map`, update the mapped doc in the same change.

## Where project rules live (code style, practices)

Not in devflow. Three layers, each with its own owner:

| Layer | Contains | Who writes it |
|---|---|---|
| The project's `CLAUDE.md` | rules for agents: style, patterns, prohibitions, "how things are done here" | you/your team (generated by the built-in `/init`) |
| The project's `docs/` | in-depth references (code style, security, testing) | you/your team |
| `.devflow/project.yml` | operational facts: env, auth, tests, git conventions | `/devflow:init` |

devflow **consumes** the rules: review judges by them (a violation of documented style is always a finding; taste against documented style is not), ralph subagents get a pointer to CLAUDE.md, sync-docs keeps the rules from rotting. To extend them — edit CLAUDE.md directly, or say "remember this as a project rule" in a session: the knowledge-sync step records the pattern.

## Privacy: devflow with no traces in git

Not everyone wants to show their team they work with agents — a legitimate choice, configured at init (or later): `project.footprint: local`. In this mode `.devflow/`, `.claude/`, and the devflow CLAUDE.md section are excluded via **`.git/info/exclude`** — a per-clone file that is never committed and invisible to the remote (unlike `.gitignore`, which would itself betray the setup). The Ralph TODO is then not committed — progress lives only on your machine (back it up yourself), and teammates don't inherit the setup. The default is `committed`: files in the repo, the team gets everything ready-made, progress survives machine changes.

## Typical scenarios

**Check that a flow works:**
`/devflow:test-flow booking: create → confirm → cancel` — wait for the table. Scenarios longer than ~3 steps run in an isolated context.

**Pick up a task from the board:**
`/devflow:task ABC-12` → the agent studies current behavior → you discuss the plan → implementation → live acceptance check → code review of the diff (it fixes real findings or surfaces judgment calls to you) → asks about the commit → asks about the tracker status.

**A large task (several days):**
`/devflow:ralph-plan <goal>` → review the TODO → then either `/devflow:ralph-build` one task at a time under your control, or `/loop /devflow:ralph-build` for an autonomous run. State is in `.devflow/TODO.md` — sessions can be killed freely.

Why a long loop doesn't degrade: every iteration runs in a subagent with a clean context window while the orchestrator holds only the loop state (the fresh-context-per-task pattern). The commit gate is deterministic: a Stop hook won't let an iteration end until the TODO checkmark is committed together with the code. Plan tasks are cut to iteration size (2–3 steps), and every acceptance criterion must be checkable mechanically — by a test or a command with expected output, not by "looks right".

**A related repository changed** (frontend for a backend dev, backend for a mobile dev, IaC repo for both — whatever counterpart you registered in `related_repos`):
`/devflow:sync <name>` → an incremental diff since the last sync → an adaptation plan → discussion → `/devflow:task` or ralph.

**A test produced a finding:**
`/devflow:issue <the finding>` → you approve the draft → an issue lands on the board → someday `/devflow:task <key>`.

## Parallel work: three levels

Parallelism means several Claude sessions at once. No magic: the tools below merely automate git isolation (worktrees) and oversight. Pick the level by actual load, not the other way around.

**Level 0 — one session (the norm).** Most days need no parallelism. One task = one session; subagents (api-tester and friends) already work "in parallel" inside it.

**Level 1 — a background subagent in a worktree (built into Claude Code).** Need "let the small task run while I focus on the main one"? Right in your session: *"start a background agent in a separate worktree: <task>"*. Claude creates the worktree, the agent works in isolation and returns the result. Nothing to install. Covers "one big + one small".

**Level 2 — Claude Squad (2–3 long-lived tasks).** When several multi-hour tasks run at once (say, `/loop /devflow:ralph-build` grinds tests in one worktree while you build a feature in another):

```
cd <project root>
claude-squad        # or your alias
```
- `n` — new session: Squad creates a worktree + branch and starts Claude in it; you give the task as a prompt
- arrows — switch between agents; the list shows who's working / waiting / done
- `Enter` — enter a session (leave with `ctrl-q`); per-agent diffs, pause/resume
- devflow skills work inside (the plugin is global)

The same thing by hand (to understand what Squad automates): `git worktree add ../proj-task1 -b feature/X && cd ../proj-task1 && claude` per terminal — then you babysit, merge, and clean up worktrees yourself. With 2+ tasks that gets old fast; that's what Squad is for.

### Rules (otherwise parallelism = chaos)

1. **Only tasks with non-overlapping blast radius run in parallel** (different services/modules). Two tasks in one service → sequential.
2. **Exactly one task owns the live environment** (docker stack, dev server, simulator). Ports and containers are machine-global: `/devflow:test-flow` and `env.up/down` from one session only. The rest work on code + isolated tests (Testcontainers-style suites use random ports — no conflicts).
3. **Persistent local data is shared**: tasks that mutate it don't run in parallel with each other.
4. Branches in worktrees follow the same `feature/{key}` convention; each agent commits only its own work.

## Troubleshooting

The first step is always the same: **`/devflow:doctor`** — it finds most of the problems below and tells you what to fix.

- **"Manifest not found"** — you're not in the project root, or the project isn't onboarded (`/devflow:init`).
- **Skills not visible** — plugin mode: check `/plugin` (installed and enabled?); dev mode: check the symlink `ls -la ~/.claude/skills/`. Then `/reload-plugins` or a new session.
- **The agent keeps stalling on permissions** — extend the allowlist in the project's `.claude/settings.json` (init generates a baseline; grow it as needed).
- **A test runs stale code** — rebuild the service before testing; if the environment is docker — `up -d --build`.
- **Jira tools not found** — `/mcp` → check the atlassian authentication.
- **protoc segfault (exit 139) in docker builds on Apple Silicon** — a known Grpc.Tools bug on linux/arm64. Fix: `platform: linux/amd64` for .NET services in compose (via a YAML anchor). Note: compose-bake may ignore `DOCKER_DEFAULT_PLATFORM`, and layer cache can mask the platform — verify hypotheses with a clean `docker build --platform ...`.
- **Scripts in `docker-entrypoint-initdb.d` "don't work"** — they only run on first volume initialization. On an existing volume create databases manually (commands belong in the manifest's `db` section).
- **Port 5432 is busy** — the machine may host a shared postgres for other projects; map the containerized DB to another host port (e.g. 5433) — inside the docker network nothing changes.
- **"Permission denied" from a hook in every session** — the hook script lost its executable bit. Fix: re-run `install.sh` (idempotent, repairs exec bits) or `chmod +x <plugin>/hooks/*.sh`. The hook doesn't block work — it only makes noise.
- **Session drift (long sessions degrade)** — how to notice: watch the mandatory formats, they double as canaries. A close-the-loop without the review handoff block, an issue created without a draft shown, a commit without asking — any of these means the session has drifted past its rules. What to do: don't argue with a drifted session — re-anchor. Invoke the skill again (skills reload their full protocol on every call), or just start a fresh session: state survives by design (manifest, `TODO.md`, `INIT.md`, sync baselines all live in files). A trivial ritual staying intact proves nothing — cheap habits self-reinforce through the transcript and outlive the rules that matter, which is why the canaries here are the *substantive* formats. Either way, drift is an inconvenience, not a catastrophe: volume destruction, base-branch commits, and tracker mutations are gated by hooks and permissions that don't depend on the model remembering anything.

---
*This document is updated together with the plugin. Found a discrepancy — that's a bug: fix it or report it.*
