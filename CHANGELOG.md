# Changelog

## 0.14.0 — 2026-06-12

Stack-agnostic release: devflow serves any repo type, not just backends — and now says so everywhere.

- **init detects the project type first** (backend / frontend / mobile / library-CLI / infra-as-code / monorepo mix) and explores, interviews, and validates per type: a frontend gets dev-server/e2e questions, an IaC repo gets plan/validate, nobody gets irrelevant DB questions. `project.type` recorded in the manifest.
- **Tier-2 gaps generalized**: the constant is "agents can exercise the project end-to-end without a human" — headless auth, seed/fixture data, and a working change→run→observe loop, each in the type's own terms.
- **Empty optional manifest sections (auth, db, services, related_repos, tracker) = "not configured", never a failure** — encoded in the template, doctor, init validation, and test-flow.
- test-flow/api-tester: flows map to the project's own surface (API endpoints, UI routes via the project's e2e runner, CLI invocations, plan/validate) — curl is the tool for HTTP, not the definition of a flow.
- doctor: docker required only when the manifest references it.
- Sync descriptions caught up with the implementation (repo-agnostic since 0.4.0): examples now cover frontend, backend, mobile, shared contracts, infra-as-code; plugin.json no longer says "frontend sync"; template shows multiple counterpart examples.

## 0.13.2 — 2026-06-12

- README polish.

## 0.13.1 — 2026-06-12

- Docs rewritten in English and addressed to new users: README and docs/GUIDE.md (replaces GUIDE.ru.md). Author-internal framing ("handoff checklist") reworked into a user-facing "verify your installation"; legacy migration notes dropped.

## 0.13.0 — 2026-06-12

- **Marketplace packaging**: the repo is now its own plugin marketplace (`.claude-plugin/marketplace.json`) — install with `claude plugin marketplace add kebabovicz/devflow` + `claude plugin install devflow@devflow`. Closes the last Roadmap item and the reviewer's registry confusion: installed this way, devflow appears in the plugin registry like any other plugin.
- Two install modes documented: marketplace (users; updates via `claude plugin update`) vs symlink dev-mode (developing devflow itself; edits take effect immediately). One at a time — both together double-load everything.

## 0.12.0 — 2026-06-12

Hardening release driven by a cold adversarial review (fresh session, no author context — a transfer rehearsal).

- **guard.sh holes closed**: `docker-compose` (V1 hyphenated) now blocked alongside `docker compose`; `DEVFLOW_ALLOW=1` bypass anchored to a leading assignment (the string inside an echo/comment/argument no longer disarms the guard); quoted YAML values (`base_branch: "main"`) no longer silently disable checks; commit anchor tolerates leading whitespace, subshell `(` and `VAR=val` prefixes; `git -C <path> commit` checks the branch of the TARGET repo, not the session cwd.
- **Honest limits documented** in the script header and README: the guard is a floor against accidents, not a sandbox — arbitrary wrappers (`bash -c`) can smuggle commands past regexes.
- **doctor: hook REGISTRATION test** — the script working is not the hook firing. New check deliberately runs a harmless command containing the dangerous literal from the project root and expects its own tool call to be BLOCKED (the inverse of the 0.5.1 assembly trick); hooks are never reported healthy on script tests alone. Stop-gate self-test now covers the exit-2 path via a disposable sandbox.
- **ralph-stop-gate**: quoted `todo:` paths handled; empty-cwd behavior aligned with guard (fail-open); `footprint: local` inertness documented (TODO is git-excluded there — gate cannot fire; README states it).
- README/GUIDE: leaked project-specific issue-key examples really neutralized to `ABC-12` this time; GUIDE install URL concretized; review skill description clarified vs the built-in single-pass code-review.
- Review's headline finding ("hooks not registered at all") was a FALSE POSITIVE — confirmed live: the hook input `cwd` is the session's directory at call start, so testing with `cd <dir> && <cmd>` in one call evaluates the manifest of the OLD cwd. Both reviewer and verifier initially fell into the same trap; the registration test above exists so nobody falls into it silently again.
- Invocation-policy criterion restated correctly (0.11.1 wording was wrong): skills are slash-only not because they are "state-changing" but because they are heavy entry points needing an explicit goal (init, update, sync, ralph-*); task/issue/review also change state yet auto-invoke — their actions are gated inside the skill instead.

## 0.11.2 — 2026-06-11

- install.sh/GUIDE: Atlassian MCP endpoint updated to streamable HTTP (`/v1/mcp`) — the SSE endpoint is deprecated and shuts down 2026-06-30 (noticed live in a task run).
- task: the closing issue comment must carry the outcome (decision, evidence, commit ref) — a bare status transition is not a closed task; for research/decision tasks the comment IS the deliverable (a real run moved an issue to done without recording the investigated decision).

## 0.11.1 — 2026-06-11

- research: description strengthened with explicit trigger phrases (incl. Russian) so conversational asks ("давай проведём ресёрч") reliably auto-invoke the skill. Reminder of the invocation split: safe/read skills auto-invoke by intent; state-changing ones (init, update, sync, ralph-*) stay slash-only by design.

## 0.11.0 — 2026-06-11

- **sync-docs: parallel fan-out for full audits** — docs partitioned into 3–4 area buckets (manifest+CLAUDE.md isolated in their own bucket), one docs-sync agent per bucket spawned in parallel, reports aggregated into a single digest. Background execution offered so the session stays usable during the audit. Motivated by a real 25-minute serial full audit. Small scopes (≤3 docs) stay single-agent.

## 0.10.1 — 2026-06-11

- research: context7 is the first stop for library/framework/SDK questions; when its MCP is absent the skill offers the one-time `claude mcp add` setup and degrades gracefully to web search. install.sh mentions the optional setup.

## 0.10.0 — 2026-06-11

- **`/devflow:research`**: decision-grade web research with the methodology baked in — source hierarchy (primary > experience reports > community > SEO), mandatory contrarian pass ("X problems", "why we moved away"), triangulation (2+ independent sources per finding), dated facts, confidence grading (established/likely/disputed/unverified), explicit minority view and "what remains unknown". Heavy digs fan out to subagents; the session keeps conclusions, not raw search dumps. Works outside devflow projects too.

## 0.9.1 — 2026-06-11

- fix: ralph-stop-gate.sh shipped without the executable bit → "Permission denied" noise on every session stop (the chmod was lost to a tooling failure during 0.6.0). install.sh now chmods all hook scripts as a safety net; troubleshooting entry added.

## 0.9.0 — 2026-06-11

- **`/devflow:review`**: iterative review-fix-review loop until a pass comes back clean ("until 10/10"). The project's documented rules are the rubric and outrank generic taste. Built-in convergence rules: empty pass = success (never invent nits), fix-reversal = stop and surface, 3-pass cap with an honest residue assessment, every finding must cite its rule/defect class. Follows the session model — run in the strongest session for the polish workflow.
- init: projects without CLAUDE.md get pointed to the built-in `/init` — devflow consumes project rules, it doesn't author them.
- GUIDE: "where project rules live" section (CLAUDE.md / docs / manifest layering and how to extend each).

## 0.8.0 — 2026-06-11

- **`project.footprint: committed | local`** — privacy mode: `local` keeps devflow invisible in git (`.devflow/`, `.claude/`, CLAUDE.md section go to `.git/info/exclude` — never `.gitignore`, which is itself committed and would betray the setup). Ralph commits code only; TODO/manifest live on the machine. Asked during init interview, shown by `/devflow:config`. Trade-off stated openly: progress doesn't survive machines, teammates don't inherit the setup.
- **init re-run protection**: init on an onboarded project stops and offers `doctor` / `config` / `update` instead of overwriting earned knowledge; re-init only on explicit insistence.
- Uniform onboarding gate: every project-scoped skill (task, issue, sync, sync-docs, ralph-plan) now stops with a `/devflow:init` pointer when there is no manifest.

## 0.7.0 — 2026-06-11

- **`/devflow:config`**: read-only view of the project's devflow configuration — env, auth (recipe + verification status), tests, data policy, git conventions, tracker, related repos, ralph state, docs map; flags every `# TODO`/`UNVERIFIED` setting nobody confirmed yet.
- **init: settings review step** — before writing the manifest, the effective configuration is shown as a table (value + origin: derived/answered/default/TODO) and the user adjusts it there; defaults are proposals, not decisions.
- **init: answer validation** — enums (tracker system, relationship, on_done), reality checks (base branch and repo paths exist, patterns contain required placeholders, tracker url answers); unsupported asks are refused with the closest supported option named, never silently written.
- Scrubbed the last project-specific examples (issue keys, branch names) from skills, template and guide — examples are now neutral (`ABC-12`).

## 0.6.1 — 2026-06-11

- Model policy: api-tester and docs-sync pinned to `model: sonnet` (mechanical work — saves the session model's rate limits); ralph-build's implementation subagent explicitly inherits the session model (writes production code — never downgrade).

## 0.6.0 — 2026-06-11

Patterns adopted from the wider agentic-engineering ecosystem (GSD's fresh-context execution, Willison's red/green TDD), after comparing devflow against BMAD/GSD/SpecKit.

- **ralph-build: fresh context per iteration** — implementation + verification are delegated to a subagent with a clean context window; the orchestrating session holds only the loop's state. Fixes the quality decay of long `/loop` runs in a single accumulating context (GSD's core insight). Trivial tasks may still be done inline.
- ralph-build: the subagent's report is a claim — the orchestrator re-verifies (diff against spec, re-run "done when") before committing.
- ralph-plan: task sizing formalized — 2–3 concrete steps, ~half a fresh context window; every AC must map to a mechanically checkable pass/fail (executable test where a suite exists).
- ralph-build: red/green when tests are the AC — failing test seen red before implementing.
- **Stop hook `ralph-stop-gate.sh`**: deterministic commit gate — stopping with uncommitted ralph-TODO changes is blocked (once; fail-open; loop-protected via `stop_hook_active`). Yesterday's "tasks checked off but never committed" failure is now mechanically impossible, not just textually discouraged.
- doctor: layer 1 now self-tests the stop-gate alongside guard.sh.

## 0.5.2 — 2026-06-11

- manifest/init: `tracker.labels` is the team's area routing (e.g. BACKEND/FRONTEND/DEVOPS), asked during init interview — was a hardcoded `[devflow]` default that polluted real boards.
- ralph-build: commit is now a hard iteration gate — TODO checkmark and code go in ONE commit (was: commit, then mark done — the trailing TODO edit left the tree dirty and later iterations stopped committing entirely; found by the first real autonomous run, tasks 5–9 of 9 were left uncommitted with tests green).
- ralph-build: clean-tree invariant at iteration start — leftover changes from a dead iteration are committed before new work begins.
- ralph-plan/build: TODO is one flat checklist, tasks checked off in place — separate Pending/Completed sections drifted apart during the run.

## 0.5.1 — 2026-06-11

- doctor: guard self-test assembles the dangerous string at runtime (`printf … %s` prune) — the literal string in the test command triggered the session's own guard hook, making the self-test unrunnable inside guarded projects. Found by doctor's first run on itself.

## 0.5.0 — 2026-06-11

- **`/devflow:doctor`**: read-only diagnostics in three layers — installation (deps, guard self-test), project (manifest health, TODO/UNVERIFIED markers, committed permissions), and live (`doctor full`: env health, auth recipe, test run, tracker reachability). Every non-green check comes with a fix hint; verdict HEALTHY / DEGRADED / BROKEN.

## 0.4.0 — 2026-06-11

- **`/devflow:sync <repo>`** (ex-`sync-front`, breaking): generalized to any related repository. Manifest `frontend:` section replaced by `related_repos:` (name → path/branch/relationship: consumer|provider|sibling). The same skill now serves backend and frontend developers symmetrically. Sync state moved to `.devflow/sync/<name>.json`. Migrate manifests with `/devflow:update`.

## 0.3.0 — 2026-06-11

- **Guardrails (hooks)**: deterministic PreToolUse protection — destructive volume commands (`down -v`, `volume rm/prune`) and commits on the base branch are blocked in devflow projects. Fail-open, scoped to projects with a manifest, `DEVFLOW_ALLOW=1` escape hatch (explicit user request only).
- **install.sh**: one-command setup with dependency checks.
- Guide: parallel-work levels (single session → background worktree agent → Claude Squad), "when NOT to use devflow" section, troubleshooting additions (protoc/arm64, initdb on existing volume, busy 5432).
- Team permissions guidance: project allowlist belongs in committed `.claude/settings.json`, not gitignored `settings.local.json`.

## 0.2.0 — 2026-06-10

- **`/devflow:task`** (ex-`work`): full task pipeline — board question, branch from fresh base (`git` manifest section), live AC verification, built-in code-review step, knowledge sync, user-gated commit/push/status transitions.
- **`/devflow:issue`**: file tracker issues (Jira via MCP, REST fallback) from findings, draft + approval flow.
- **`/devflow:update`**: additive manifest migration after plugin updates.
- Manifest: `git` (base branch, branch/commit patterns, on_done), `tracker` (+wip/done statuses), `db` (persistent-data policy, snapshot/restore) sections.
- Data policy: local volumes are persistent test state; agents never destroy them.
- `init`: interview step for non-derivable preferences; mandatory live validation before reporting success.
- docs/GUIDE.ru.md — full Russian guide.

## 0.1.0 — 2026-06-10

- Initial skeleton: manifest template, skills (init, test-flow, ralph-plan, ralph-build, sync-front, sync-docs), agents (api-tester, docs-sync).
