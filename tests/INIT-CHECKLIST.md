# Init verification checklist

`/devflow:init` is a model-driven skill — it cannot be CI-tested deterministically.
This checklist plus `tests/fixtures/` turns "init works for any stack" from a claim
into a repeatable verification: run it after any change to `skills/init/SKILL.md`
or `templates/project.yml`.

## How to run one fixture

```bash
cp -r tests/fixtures/<name> /tmp/init-check-<name>
cd /tmp/init-check-<name>
git init -b develop && git add -A && git commit -m fixture
claude   # then: /devflow:init
```

Answer the interview with the "expected answers" below. The fixtures are skeletons,
not buildable projects — **live validation is expected to be deferred**: every
command-like field must end up marked `# UNVERIFIED`, and init must say so in its
final report. An init that reports success without UNVERIFIED markers on a fixture
has hallucinated a validation — that is a failed check.

## Pass criteria (every fixture)

- [ ] Type detected correctly BEFORE exploring (see table) and written to `project.type`.
- [ ] No irrelevant interview questions (e.g. no DB/data-policy question for react-vite, angular, flutter, terraform).
- [ ] `.devflow/INIT.md` created first, checked off during the run, deleted at the end (deferred validation counts as an end).
- [ ] Manifest fields match the table; nothing invented — underived fields are empty with `# TODO`.
- [ ] Settings review table shown before writing (value + origin per field).
- [ ] No absolute machine paths / username / personal email in `.devflow/project.yml` or `.claude/settings.json` (machine-truth rule).
- [ ] No tracker or Confluence mutation tools in the proposed allowlist.
- [ ] Re-running `/devflow:init` afterwards STOPs and offers doctor/config/update.

## Per-fixture expectations

| Fixture | Expected `type` | Key manifest fields init must derive | Interview answers to give |
|---|---|---|---|
| `dotnet-webapi` | backend | `env.up` from docker-compose.yml; `services.api` with HOST port 8080 (never the container port); db section noticed (postgres volume = persistent); test.run mentions the .sln/test project | tracker: none; base branch: develop; footprint: committed |
| `react-vite` | frontend | `env.up: npm run dev` (dev server, port 5173); `test.run: npm test` (vitest); proxy to `:8080` noticed as a related-repo/backend hint — init should ASK about the API counterpart, not invent it | tracker: none; no related repo ("just exploring") |
| `flutter-app` | mobile | simulator/emulator workflow questions asked; `test.run: flutter test`; no docker/db questions | tracker: none |
| `angular-app` | frontend | `env.up: npm start` (ng serve, port 4200); `test.run: npm test` | tracker: none |
| `terraform-infra` | infra | validate/plan as the exercise loop (`terraform validate` / `plan`); NO auth/db/env.up-as-server questions; state policy asked | tracker: none |
| `monorepo-mix` | mixed | ONE manifest at the repo root; workspaces (`apps/web`) + `services/api` both identified; `env.up` = whole-stack (compose); per-area test commands recorded (comments ok) | tracker: none; footprint: committed |

## Recording a run

Append a line to the table below (newest first). A ✗ on any pass criterion is a
bug in the init skill — file/fix it before shipping the change that caused it.

| Date | Plugin version | Fixtures run | Result | Notes |
|---|---|---|---|---|
| — | — | — | — | no runs recorded yet |
