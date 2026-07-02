# devflow

**A process harness for Claude Code: development discipline for coding agents.**

Long agent sessions drift: "done" that only compiled, rules quietly forgotten by hour six, a careless `down -v`, onboarding from zero on every new project. devflow turns the discipline into mechanics:

- **skills advise** — processes for tasks, flow testing, review, tracker and docs hygiene;
- **hooks enforce** — deterministic guards: destroying docker volumes or committing to the base branch hits a hard stop, whatever the model "thinks";
- **the manifest knows your project** — env, auth, tests, conventions in one file; agents hardcode nothing, so the same plugin fits a microservice fleet and a weekend pet project.

You set the goals and make the decisions — agents do the work: bring up the environment, implement, verify against live services, commit by your conventions, keep the tracker honest. Large tasks survive any session: plans and progress live in files, not in the context window (Ralph-style).

It is not a framework — devflow never touches your code's architecture.

**📖 Full guide: [docs/GUIDE.md](docs/GUIDE.md)** — why, how it works, command reference, scenarios, parallel work, troubleshooting.

## One engine, a thin layer per project

```
devflow plugin (this repo, portable)        each project (thin layer)
├── skills    /devflow:*                    ├── .devflow/project.yml   ← the manifest
├── agents    api-tester, docs-sync         ├── .devflow/specs/, TODO.md (Ralph state)
├── hooks     guard, ralph-stop-gate        └── .claude/CLAUDE.md, settings.json
└── templates project.yml
```

Everything project-specific lives in the manifest: how to start the environment, obtain an auth token, run tests, where the docs live, which repos are related, which tracker and git conventions apply. Onboarding a new project is one command: `/devflow:init` explores the repo and builds the manifest with you.

## Install

**As a plugin (recommended):**

```bash
claude plugin marketplace add kebabovicz/devflow
claude plugin install devflow@devflow
```

Update: `claude plugin update devflow@devflow` (or via `/plugin`). If the manifest template changed, run `/devflow:update` in your projects.

**Dev mode (for working on devflow itself):**

```bash
git clone https://github.com/kebabovicz/devflow ~/devflow && ~/devflow/install.sh
```

Symlink instead of install — edits take effect immediately. Update: `git -C ~/devflow pull`.

> ⚠ Pick **one** mode: plugin + symlink together loads everything twice. After switching modes, start a new session.

### Verify your installation

Four steps, each proving the previous one — all green means devflow works as designed:

1. Install (either mode above);
2. `/devflow:doctor` — installation diagnostics: dependencies, hook **registration** test (not just the scripts);
3. `/devflow:init` in a project — onboarding with mandatory live validation (the auth recipe is proven by executing it, not by reading code);
4. `/devflow:test-flow <any harmless scenario>` — end-to-end proof: environment + auth + API.

Something off? `/devflow:doctor` first — it finds most problems and tells you what to fix.

## Commands: which one when

| Situation | Command |
|---|---|
| New project (once) | `/devflow:init` |
| "Something's broken" / new machine / after an update | `/devflow:doctor` (`full` adds live checks) |
| "How is this project configured?" | `/devflow:config` |
| Manifest may have drifted from reality / clear `UNVERIFIED` homework | `/devflow:revalidate` — re-runs init's live validation, updates the markers |
| Check whether a business flow works | `/devflow:test-flow <flow>` |
| A regular task — from the tracker or as plain text | `/devflow:task <ABC-12 \| text>` — full cycle with live acceptance checks, review, and commit/status gates |
| A finding worth keeping came out of a test or discussion | `/devflow:issue <finding>` — draft → your approval → tracker issue |
| Large task (multiple commits/sessions) | `/devflow:ralph-plan <goal>` → review the TODO → `/loop /devflow:ralph-build` |
| Polish code "until 10/10" | `/devflow:review [branch \| PR]` — review→fix→re-review loop against your project's own rules |
| Understand a topic before deciding | `/devflow:research <question>` — methodology-driven research: primary sources, contrarian pass, confidence-graded digest; heavy multi-angle digs ask before spending, `quick <question>` for a cheap single-pass answer |
| A related repo moved ahead (frontend, backend, mobile, shared contracts, infra-as-code — any counterpart) | `/devflow:sync <name>` |
| Docs drifted from the code | `/devflow:sync-docs` |
| Work finished (with or without devflow) — "what exactly should I check?" | `/devflow:handoff` — risk-ranked review handoff: judgment calls first, mechanical changes as a count, two-minute re-checks |
| Plugin updated, manifest is behind | `/devflow:update` |
| A typo / trivial change you can eyeball | no devflow — just ask in the session |

## Always-on protection (hooks)

- **guard** — blocks destruction of docker volumes (`compose down -v`, `compose rm -v`, `volume rm/prune`, `system prune --volumes`; both `docker compose` and `docker-compose`) and the three ways history lands on the base branch: commits on it, pushes to it (`push origin <base>`, `HEAD:<base>`, refspec deletion), and local merges/cherry-picks into it (`git pull` on base stays allowed — that's the sanctioned update);
- **ralph-stop-gate** — a Ralph iteration cannot end with uncommitted work: code and its TODO checkmark land in one commit. *Inactive in `footprint: local` mode* — the TODO lives outside git there, the commit gate is then enforced by skill rules only;
- **session-digest** — every session opened in a devflow project starts with the load-bearing conventions in context (base branch, branch/commit patterns, data policy) — deterministic anti-drift: the rules are present from token zero, not from the first skill call.

Hooks are deterministic (not prompt text), active only in projects with a manifest, and fail-open — a broken hook never paralyzes a session. Honest limits: this is a floor against accidents and model forgetfulness, not a sandbox — an arbitrary wrapper (`bash -c '…'`), a multi-line command, or a compound command that changes state before acting (`git checkout main && git commit`) can get past the regexes. The trade-off cuts the safe way too: a dangerous literal inside a harmless argument (a commit message quoting a docker command) gets blocked. Verify hooks are actually live with `/devflow:doctor` (registration test, not just the scripts). The hook logic itself is covered by a committed regression suite — `tests/run.sh`, run in CI on every change.
