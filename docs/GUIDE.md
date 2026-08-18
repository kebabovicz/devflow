# devflow — the guide

A Claude Code plugin that turns development into a managed process: you set tasks and make decisions; agents explore, implement, test, and keep the records. One plugin — many projects: everything project-specific lives in the `.devflow/project.yml` manifest; the plugin itself knows nothing about your project.

---

## Why

| Pain | How devflow addresses it |
|---|---|
| Testing the API by hand is slow | `/devflow:test-flow` — the agent brings up the environment, obtains a token, runs the scenario, returns an expected-vs-actual table |
| Findings from tests get lost in chat | `/devflow:issue` — a finding becomes a tracker issue (with evidence and a done-criterion) |
| The agent invents the implementation you never specified | `/devflow:map` — a decision map with an explicit detailed-design stage: interfaces, seams, data shapes, edge behavior. What is written down is not invented |
| Large tasks don't survive a session | Decisions live in the map, progress in its tickets — both on disk, so sessions are disposable |
| Documentation rots | Knowledge sync: at the end of every task the agent updates docs/manifest against the diff |
| Moving your setup to a new project | `/devflow:init` — one-command onboarding |

A real example from the first day of production use: a flow test found that a service published events past the DB outbox → one command filed a tracker issue → during implementation the agent noticed the ticket contradicted the codebase and asked how to proceed → implementation → a re-run caught the outbox row live → the issue was closed with evidence.

## How it's built

```
The plugin (this repository)         Each project
├── skills/  — /devflow:* commands   ├── .devflow/project.yml  ← manifest: env, auth,
├── agents/  — subagents             │     ports, tests, docs, tracker
│   ├── api-tester  (tests flows)    ├── .devflow/maps/  ← decision maps (never committed)
│   └── docs-sync   (audits docs)    ├── .devflow/specs/  ← standalone specs
└── templates/ — manifest template   ├── .out-of-scope/  ← what this project won't do
                                     └── .claude/CLAUDE.md  ← project knowledge
```

**Guardrails (hooks)** — hard limits that work deterministically (the model cannot "forget" them; Claude Code itself enforces them): destroying docker volumes with data (`down -v`, `volume rm/prune`); landing history on the base branch by any local route — commit on it, push to it, merge/cherry-pick into it (`git pull` on base stays allowed: updating base from origin is the sanctioned flow); destroying uncommitted work (`git reset --hard`, forced `git clean`). Active only in projects with a manifest; the escape hatch is a `DEVFLOW_ALLOW=1` prefix, which agents may use only when you explicitly asked for the blocked action. Scripts are fail-open: any error means allow — a broken guard never paralyzes sessions.

Principles:
- **The manifest is the single source of project specifics.** An agent reads the yml and knows how to start the environment, get a token, find the docs.
- **Local by default, tracker optional.** Maps, decisions, and tickets are files; a tracker is an integration offered when configured, never a prerequisite. Decision maps stay out of git at any footprint — a planning draft is the author's thinking, not team documentation.
- **What is decided is written; what is written is not invented.** Every stage of a map produces decisions in files. An agent implementing from a design document has nothing left to guess — and the guessing is where "not what I meant" comes from.
- **Progress lives in files, not in context.** Any session can be killed — state survives.
- **One voice.** Every skill asks and reports by one style rule (`skills/OUTPUT-STYLE.md`): plain words with terms explained at first use, front-loaded sentences, lists only where something is genuinely listed, the next action on the last line.
- **A rejection is a decision, so it gets written down.** `.out-of-scope/` keeps one file per concept — the durable reason and every prior request — and `issue`, `discuss`, and the map's charting stage check it before re-litigating a settled no.
- **Verification = executing the acceptance criteria live.** A clean build is compilation, not "done".
- **Outward actions need your confirmation**: commits, tracker issues, status transitions (autonomous `/loop` runs are the exception).
- **Subagents burn their own context**: heavy work happens in isolated windows; only the report comes back to your session.
- **Model choice follows the kind of thinking, not the importance**: mechanical agents (api-tester, docs-sync) are pinned to sonnet — saving your main model's rate limits; anything writing production code (the build implementation subagent, review) inherits the session model — no economizing there.

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

Jira/Confluence (optional, once — one MCP serves both):
```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp -s user
```
then in a session: `/mcp` → atlassian → Authenticate (OAuth in the browser; no tokens are stored anywhere). Confluence sync activates per project via `docs.confluence` in the manifest (asked during init when the tracker is Jira).

Onboarding a project: open a session in the project root → `/devflow:init`. It explores the repo, generates the manifest and permissions; gaps that require code (dev auth, seed data) are run as normal tasks with your approval.

## Command reference

| Command | What it does | When to use |
|---|---|---|
| `/devflow:init` | Project onboarding: explores the repo → interview (tracker, git conventions, data policy, footprint) → settings review → manifest + permissions + CLAUDE.md section → live validation | Once per project. Re-running is protected: init sees the manifest and offers doctor/config/update instead of overwriting |
| `/devflow:update` | Migrates the manifest to the current template: additive only, never overwrites | After a plugin update, if the manifest template changed |
| `/devflow:doctor [full]` | Diagnostics: dependencies, hook registration + script self-tests, manifest health, permissions; `full` adds live checks (env, auth recipe, tracker) | First command when "something's broken"; after install/update; on a new machine |
| `/devflow:config` | The project's current configuration, readable: env, auth, tests, git conventions, tracker, related repos + a list of unconfirmed settings | "How is this set up?" — without digging through yml. Read-only; change things by editing the manifest or just asking |
| `/devflow:revalidate [section]` | Init's live validation, on demand: executes every filled command-like field (env up + health, auth recipe, tests on confirmation, service ports) and updates `# VERIFIED <date>` / `# UNVERIFIED — reason` markers in place. Doctor finds, revalidate executes and records | Manifest may have drifted (env/infra changed, project evolved); clearing `UNVERIFIED` homework after a deferred init validation |
| `/devflow:test-flow <flow>` | Verifies a business flow against live services: starts the environment, authenticates, runs the scenario, reports expected vs actual. `swarm` + several flows runs the suite in parallel — shared env/auth set up once, one agent per flow, fixture collisions serialized | After API changes; checking "does it actually work"; verifying tasks; a whole suite at once with `swarm` |
| `/devflow:discuss <idea>` | Pre-implementation interview: rounds on real forks only, asked as numbered prose questions each carrying a recommended answer (option menus only for a genuinely closed, exclusive fork — a label cannot hold a qualification, and the qualification is usually the load-bearing part), plus contentious calls argued with trade-offs and an explicit "unless you say otherwise" assumption ledger → an approved spec/concept file. Two grounds: a feature in an existing repo (axes: scope/non-goals, edge behavior, data contracts, integration, quality bar) or a greenfield idea with no repo yet (axes: audience and pain, core loop, MVP cut, platform/stack, data, distribution). "I don't know" gets proposed options → narrowing follow-ups → an honest open question + `/devflow:research`, never a silent pick. Rounds follow the decision tree: the frontier is every question whose prerequisites are settled, asked together and recomputed from the answers; facts are looked up by a subagent instead of asked, and a running lookup blocks only the questions downstream of it. Never implements | The thing exists as a picture in your head and the gap between "как я это представлял" and what gets built is expensive. Called from `/devflow:map` it resolves one `grilling` decision and hands it back; standalone it writes its own spec |
| `/devflow:map <goal>` | Decision map: recon of the current code → requirements → concept → spec → **detailed design** (interfaces and seams, data shapes and contracts, behavior at the edges, rejected alternatives) → slicing into vertical-slice tickets. Decisions are tickets of two types — `research` closed by the agent alone, `grilling` closed only in conversation with you — worked frontier-first, one per session. The map itself is an index: it gists each decision and links to the ticket holding it, and tracks the fog it has not charted yet. A shape that is expensive to change — a module's interface, an API contract, how responsibilities split — gets designed three ways in parallel under different constraints, compared on depth, locality and seam placement, and one recommended | The stage that was missing. Anything past a one-line fix starts here; the map lives in `.devflow/maps/<effort>/` and never enters git. Output: `spec.md`, `design.md`, `tickets/` |
| `/devflow:task <ticket \| ABC-12 \| text>` | Full task cycle: understand → implement → verify acceptance live → (asking first!) commit and close | The main work command. From a map ticket the thinking is already done — it implements what was decided; a tracker key pulls the issue; plain text means the task was never designed, so it offers a map first |
| `/devflow:diagnose <symptom>` | Diagnosis discipline: **no hypotheses until one command already goes red on this bug**, built from the project's own commands (`test.run`, `env.up` + `auth.recipe` + `services`, the `api-tester` agent past three steps) and required to assert the symptom you described, deterministically, in seconds, unattended. Then reproduce and minimise, three to five falsifiable hypotheses ranked and shown before any is tested, one variable per probe with `[DEBUG-xxxx]` tags, a regression test written before the fix — or the missing seam reported as an architectural finding. A repro that needs a person becomes a script (`step`/`capture` → `KEY=value`), so the run after the fix is the same run | Something is broken, throwing, or slow and the cause is not obvious. `/devflow:task` routes bugs here first |
| `/devflow:issue <finding>` | Drafts an issue per your conventions → your approval → files it in the tracker | When a test or discussion produced a finding that must not be lost |
| `/devflow:review [branch \| PR]` | Iterative review along **two independent checks**: Standards (the project's own rules plus an always-on code-smell baseline) and Requirements (does the diff implement exactly what the ticket and `design.md` decided — missing, unasked-for, or implemented wrong). They run without seeing each other and are reported side by side, never merged, since the merged version hides the quieter one. Then fix accepted findings → re-review, until a clean pass (max 3 rounds, anti-churn rules). `swarm` runs the review pass as parallel per-dimension finders + adversarial verifiers (local Workflow, opt-in) — distinct from the cloud-billed `/code-review ultra` | "Polish until 10/10". A branch after an autonomous run; for a large risky diff prefer `/code-review ultra` or `review swarm` |
| `/devflow:research [quick] <question>` | Research with the methodology built in: primary sources > team experience > forums > SEO; a mandatory contrarian pass; triangulation; a digest with confidence grades and an honest "what remains unknown". Multi-angle digs fan out to subagents **behind a cost gate** (announced before spending, ~15 tool calls per subagent); `quick` = inline single pass, no subagents — cheap, every finding carries its (mostly weaker) confidence grade; `swarm` = a deterministic Workflow dig (multi-modal sweep, contrarian as its own stage, adversarial claim verification, loop-until-dry) | Before choosing a technology/approach; "what's current practice"; collecting real-world experience including minority views. `quick` for low-stakes questions, never for irreversible decisions; `swarm` for a decision worth a deep verified dig. Works outside devflow projects too |
| `/devflow:build` | Autonomous mode: one ready ticket per iteration — implementation goes to a **fresh-context** subagent, the orchestrator re-verifies the diff and the acceptance checks itself, commits the code, marks the ticket done. A gap in the design blocks the ticket instead of being guessed at | Grinding a map's tickets unattended: `/loop /devflow:build`. Under your eye, one ticket at a time, use `/devflow:task <path>` instead |
| `/devflow:sync <name>` | Diff of a related repo (from the manifest's `related_repos`) since the last sync → change classification → an adaptation plan | Any counterpart repository moved ahead: the frontend for a backend dev, the backend for a mobile dev, infra-as-code for either, a shared contracts repo for everyone; `relationship` (consumer/provider/sibling) in the manifest sets the direction. Single-repo projects simply never configure it |
| `/devflow:sync-docs` | Audits docs (+manifest, +CLAUDE.md) against the code, fixes what's stale. Mapped Confluence pages are audited and updated the same way (draft → your approval, via the Atlassian MCP). Full audits run as a parallel fan-out: 3–4 subagents by area + one aggregated digest; can run in the background. `swarm` upgrades this to a Workflow pipeline that independently confirms each claimed code bug before it reaches the digest | Periodically; after large merges made outside devflow |
| `/devflow:handoff [branch \| ticket]` | Two modes, picked by whether the work is finished. **Review handoff** for a diff: risk-ranked attention map (judgment calls + auto-red changes → spot-check items → mechanical count) and two-minute re-checks with actually observed outputs. Honest limit: only the re-checks are falsifiable — the rest is the agent's self-assessment, a floor for attention, not proof | Your verification time is the bottleneck. **Work handoff** for work you are stopping mid-way: what is done and where it lives (committed vs sitting in the tree), the exact stopping point, the dead ends worth not re-walking, what is left — written into the ticket, or into the effort's `HANDOFF.md`. Uncommitted work is settled explicitly, since a dirty tree does not travel | Built into `/devflow:task` close-the-loop; standalone — for work done without devflow skills, by another agent, or handed to the next session. **Called with a word meaning "continue"** it works the other way: finds the last handoff (asking which, when several exist), checks its claims against the repository — named commits present, described working tree matching `git status`, ticket status still what it assumed — reports the drift first, shows where it would continue, and waits for you |

Useful built-in Claude Code commands alongside devflow:

| Command | Why it pairs well |
|---|---|
| `/loop /devflow:build` | The autonomous closed loop: the agent grinds the map's tickets until done or blocked |
| `/code-review` | Built into the `/devflow:task` pipeline (the pre-commit step). Manually: on a whole branch after a `/loop` run; `/code-review ultra` — deep multi-agent cloud review for big features |
| `/clear` | Context hygiene: one task = one session |
| `/reload-plugins` | Pick up plugin changes without restarting the session |

## When NOT to use devflow (choose the entry by task size)

devflow is not a mode — it is a set of entry points. For small things the full pipeline is overkill, by design:

| Task | The right entry |
|---|---|
| A typo, a small refactor, something you can eyeball | just ask in the session — no skills, no ceremony |
| Anything that needs designing before it needs doing | `/devflow:map` — the default entry for real work. A two-ticket map is a valid map; the ceremony scales down, skipping it does not |
| A ticket a map already produced | `/devflow:task <path>` — implements what was decided |
| "How does this work now?", checking a hypothesis | a question, or `/devflow:test-flow` |
| A decision to sharpen, with no effort around it | `/devflow:discuss` standalone |
| A map's tickets, ground down unattended | `/loop /devflow:build` |

**task or build?** Same cycle over the same tickets; the difference is who is watching. `task` asks before committing, before touching the tracker, before anything outward-facing. `build` asks nothing — which is defensible only because the map already decided everything it needs, and because a gap in the design stops the ticket instead of being filled in by the agent.

Gates can be skipped deliberately ("no review, I'll look myself") — that's management, not a violation. devflow protects against skipping *by forgetfulness*, not against your decisions. Only the guardrails (irreversible actions) are always on — and they are invisible until you do something dangerous. The one step worth keeping even on small changes: if the edit touched a flow listed in `docs.map`, update the mapped doc in the same change.

## Where project rules live (code style, practices)

Not in devflow. Three layers, each with its own owner:

| Layer | Contains | Who writes it |
|---|---|---|
| The project's `CLAUDE.md` | rules for agents: style, patterns, prohibitions, "how things are done here" | you/your team (generated by the built-in `/init`) |
| The project's `REVIEW.md` (repo root) | review rules: severity definitions, nit caps, skip paths, repo-specific checks — read by the built-in code-review as its highest-priority instructions; devflow's review/task skills honor it the same way | you/your team |
| The project's `docs/` | in-depth references (code style, security, testing) | you/your team |
| `.devflow/project.yml` | operational facts: env, auth, tests, git conventions | `/devflow:init` |

devflow **consumes** the rules: review judges by them (a violation of documented style is always a finding; taste against documented style is not), build subagents get a pointer to CLAUDE.md, sync-docs keeps the rules from rotting. To extend them — edit CLAUDE.md directly, or say "remember this as a project rule" in a session: the knowledge-sync step records the pattern.

## Privacy: devflow with no traces in git

Not everyone wants to show their team they work with agents — a legitimate choice, configured at init (or later): `project.footprint: local`. In this mode `.devflow/`, `.claude/`, and the devflow CLAUDE.md section are excluded via **`.git/info/exclude`** — a per-clone file that is never committed and invisible to the remote (unlike `.gitignore`, which would itself betray the setup). Teammates then do not inherit the setup — back the manifest up yourself. Decision maps are excluded in both modes. The default is `committed`: files in the repo, the team gets everything ready-made, progress survives machine changes.

## Typical scenarios

**Check that a flow works:**
`/devflow:test-flow booking: create → confirm → cancel` — wait for the table. Scenarios longer than ~3 steps run in an isolated context.

**Design a feature before building it:**
`/devflow:map добавить экспорт отчётов` → the agent recons the current code and writes what it found → names the destination → charts the decisions it can already phrase, leaving the rest as fog → fires the `research` tickets in parallel → stops. Next session: `/devflow:map` takes the first ready decision, resolves it (with you, if it is a `grilling` one), records the answer, and clears whatever fog that answer lifted. When no decisions remain, the map writes `spec.md`, `design.md`, and the tickets — then `/devflow:task .devflow/maps/export/tickets/01-*.md` per slice, one per session.

**Pick up a task from the board:**
`/devflow:task ABC-12` → the agent studies current behavior → you discuss the plan → implementation → live acceptance check → code review of the diff (it fixes real findings or surfaces judgment calls to you) → asks about the commit → asks about the tracker status.

**A large task (several days):**
`/devflow:map <goal>` charts it and works one decision per session until the design is settled and the tickets are cut; then either `/devflow:task <ticket>` one at a time under your control, or `/loop /devflow:build` for an autonomous run. State lives in `.devflow/maps/<effort>/` — sessions can be killed freely.

Why a long loop doesn't degrade: every iteration runs in a subagent with a clean context window while the orchestrator holds only the loop state (the fresh-context-per-ticket pattern). The commit gate is deterministic: a Stop hook won't let an iteration end while a ticket is in progress and the work is uncommitted. Tickets are cut to iteration size — one vertical slice, one fresh context — and every acceptance criterion must be checkable mechanically, by a test or a command with expected output, not by "looks right". And the agent has nothing to invent along the way: the design was settled before the first ticket existed.

**A related repository changed** (frontend for a backend dev, backend for a mobile dev, IaC repo for both — whatever counterpart you registered in `related_repos`):
`/devflow:sync <name>` → an incremental diff since the last sync → an adaptation plan → discussion → `/devflow:map` when it needs designing, `/devflow:task` when it does not.

**A test produced a finding:**
`/devflow:issue <the finding>` → you approve the draft → an issue lands on the board → someday `/devflow:task <key>`.

## Parallel work: three levels

Parallelism means several Claude sessions at once. No magic: the tools below merely automate git isolation (worktrees) and oversight. Pick the level by actual load, not the other way around.

**Level 0 — one session (the norm).** Most days need no parallelism. One task = one session; subagents (api-tester and friends) already work "in parallel" inside it.

**Level 1 — a background subagent in a worktree (built into Claude Code).** Need "let the small task run while I focus on the main one"? Right in your session: *"start a background agent in a separate worktree: <task>"*. Claude creates the worktree, the agent works in isolation and returns the result. Nothing to install. Covers "one big + one small".

**Level 2 — Claude Squad (2–3 long-lived tasks).** When several multi-hour tasks run at once (say, `/loop /devflow:build` grinds tests in one worktree while you build a feature in another):

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
- **Session drift (long sessions degrade)** — how to notice: watch the mandatory formats, they double as canaries. A close-the-loop without the review handoff block, an issue created without a draft shown, a commit without asking — any of these means the session has drifted past its rules. What to do: don't argue with a drifted session — re-anchor. Invoke the skill again (skills reload their full protocol on every call), or just start a fresh session: state survives by design (manifest, the map and its tickets, `INIT.md`, sync baselines all live in files). A trivial ritual staying intact proves nothing — cheap habits self-reinforce through the transcript and outlive the rules that matter, which is why the canaries here are the *substantive* formats. Either way, drift is an inconvenience, not a catastrophe: volume destruction, base-branch commits, and tracker mutations are gated by hooks and permissions that don't depend on the model remembering anything.

---
*This document is updated together with the plugin. Found a discrepancy — that's a bug: fix it or report it.*
