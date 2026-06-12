# devflow

**A process harness for Claude Code: development discipline for coding agents.**

You set the goals and make the decisions — agents do the work: they bring up the environment, implement, verify against live services, pass review, commit by your conventions, keep your issue tracker honest, and hit a deterministic guard before destroying what must not be destroyed. Large tasks survive any session: plans and progress live in files, not in the context window (Ralph-style).

It is not a framework — devflow never touches your code's architecture. It is a harness around the agent: skills (processes), hooks (hard limits), and a manifest (project knowledge).

**📖 Full guide: [docs/GUIDE.md](docs/GUIDE.md)** — why, how it works, command reference, scenarios, parallel work, troubleshooting.

## One engine, a thin layer per project

```
devflow plugin (this repo, portable)        each project (thin layer)
├── skills    /devflow:*                    ├── .devflow/project.yml   ← the manifest
├── agents    api-tester, docs-sync         ├── .devflow/specs/, TODO.md (Ralph state)
├── hooks     guard, ralph-stop-gate        └── .claude/CLAUDE.md, settings.json
└── templates project.yml
```

Agents hardcode nothing about your project — everything comes from the manifest: how to start the environment, how to obtain an auth token, how to run tests, where the docs live, which repos are related, which tracker and git conventions apply. That is what makes devflow portable across stacks — from .NET microservices to a weekend pet project. Onboarding a new project is one command: `/devflow:init` explores the repo and builds the manifest with you.

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
| Check whether a business flow works | `/devflow:test-flow <flow>` |
| A regular task — from the tracker or as plain text | `/devflow:task <ABC-12 \| text>` — full cycle with live acceptance checks, review, and commit/status gates |
| A finding worth keeping came out of a test or discussion | `/devflow:issue <finding>` — draft → your approval → tracker issue |
| Large task (multiple commits/sessions) | `/devflow:ralph-plan <goal>` → review the TODO → `/loop /devflow:ralph-build` |
| Polish code "until 10/10" | `/devflow:review [branch \| PR]` — review→fix→re-review loop against your project's own rules |
| Understand a topic before deciding | `/devflow:research <question>` — methodology-driven research: primary sources, contrarian pass, confidence-graded digest |
| A related repo moved ahead (frontend, backend, mobile, shared contracts, infra-as-code — any counterpart) | `/devflow:sync <name>` |
| Docs drifted from the code | `/devflow:sync-docs` |
| Plugin updated, manifest is behind | `/devflow:update` |
| A typo / trivial change you can eyeball | no devflow — just ask in the session |

## Always-on protection (hooks)

- **guard** — blocks destruction of docker volumes (`compose down -v`, `compose rm -v`, `volume rm/prune`, `system prune --volumes`; both `docker compose` and `docker-compose`) and commits to the base branch;
- **ralph-stop-gate** — a Ralph iteration cannot end with uncommitted work: code and its TODO checkmark land in one commit. *Inactive in `footprint: local` mode* — the TODO lives outside git there, the commit gate is then enforced by skill rules only.

Hooks are deterministic (not prompt text), active only in projects with a manifest, and fail-open — a broken hook never paralyzes a session. Honest limits: this is a floor against accidents and model forgetfulness, not a sandbox — an arbitrary wrapper (`bash -c '…'`), a multi-line command, or a compound command that changes state before acting (`git checkout main && git commit`) can get past the regexes. The trade-off cuts the safe way too: a dangerous literal inside a harmless argument (a commit message quoting a docker command) gets blocked. Verify hooks are actually live with `/devflow:doctor` (registration test, not just the scripts).
