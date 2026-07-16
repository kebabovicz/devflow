# Changelog

## 0.24.0 — 2026-07-16

- **New skill: `/devflow:spec <idea>` — pre-implementation interview.** Closes the gap *before* ralph-plan and task: the user has a picture in their head, the agent can't read minds, and every silently-made decision is a future "это не то, что я имел в виду". The skill interrogates in rounds (AskUserQuestion, 2–4 per round, options with a recommendation — never free-text question walls), but only on real forks: a question earns its slot when different answers produce different plans AND nothing already answers it. **Two grounds**: a feature in an existing repo (homework in the code first; axes: scope/non-goals, edge behavior, data contracts, integration, quality bar) and a **greenfield idea with no repo at all** ("хочу приложение для фитнеса"; axes: audience and pain, core loop, MVP cut vs explicit LATER, platform/stack, data, distribution). Three mechanics beyond Q&A: the **"I don't know" ladder** (propose fitting options with trade-offs → if none credible, narrow with follow-up questions → else an honest open question + `/devflow:research`, never a silent pick or fake inline research), **contentious calls** (the agent argues its case once with trade-offs — participant, not stenographer; the user's decision is final and the losing option is recorded), and the **assumption ledger** (everything the agent would still decide silently becomes an explicit "unless you say otherwise" list the user confirms). Output: a spec/concept file — in `ralph.specs_dir` with a manifest, wherever the user picks without one — with a decisions log, confirmed assumptions, non-goals, and open questions; consumed by `/devflow:task` (small), `/devflow:ralph-plan` (large), or `init`+`ralph-plan` (greenfield). Hard rule: no implementation inside the skill — "it's clear enough, let me just build it" is the exact failure it exists to stop.
- **Docs**: README situation table, GUIDE command reference and entry-by-task-size table gain the spec row.

## 0.23.0 — 2026-07-08

- **`swarm` mode — opt-in multi-agent Workflow across four skills** (`review`, `research`, `test-flow`, `sync-docs`). The word `swarm` in a skill's arguments is the user's explicit opt-in to the expensive parallel path — the same contract as the cloud-billed `/code-review ultra`, but local: the skill announces the plan and token cost, fans out via the harness Workflow tool, and where that tool isn't present degrades to the skill's existing single-threaded or Agent-based path rather than failing. Rationale: a few skills gain real quality from *deterministic* orchestration (per-dimension pipelines, barriers, adversarial verify) that a model-driven single pass leaks — but tacit fan-out on every invocation would betray devflow's guardrail-first posture, so it stays behind an explicit keyword, never a default.
  - **review**: `swarm` runs the review pass as a pipeline of per-dimension finders (correctness/security/perf + every REVIEW.md check), each finding then confirmed by adversarial verifiers (skeptics prompted to refute; survives on majority-confirm) before entering the same triage→fix→re-review loop. Distinct from `/code-review ultra` — that runs billed in Anthropic's cloud; `swarm` fans out inside the session.
  - **research**: upgrades the existing behind-a-cost-gate fan-out to a deterministic Workflow — multi-modal sweep (angle × source-type), contrarian as its own parallel stage, adversarial claim verification before a confidence grade, loop-until-dry. Now three depths: `quick` / full / `swarm`.
  - **test-flow**: `swarm` + several flows runs a suite in parallel — shared env/auth established once in the main session, one agent per flow, fixture-colliding flows serialized rather than raced. A single flow stays on the api-tester path (fan-out buys nothing).
  - **sync-docs**: upgrades the bucket fan-out to a verified pipeline — each claimed 🐛 (doc reveals a code bug) is re-checked by an independent agent before the digest; an unsubstantiated one is downgraded to 📝 or dropped with a note. Confluence stays in the main session (no MCP inside Workflow agents).
- **Docs**: README and GUIDE tables document `swarm` alongside `quick`, so the mode is discoverable and `sync-docs` won't flag it as drift.
- Deliberately NOT added: `swarm` on `task`/`issue`/`doctor`/`handoff` (nothing to parallelize there); Workflow as any skill's default (opt-in only, by design).

## 0.22.3 — 2026-07-02

- **ralph-build: loop end = handoff** — when a run finishes (TODO fully checked, or stopped on blockers), the loop offers a review handoff for the whole task branch, with the TODO's `⚠ judgment call` notes feeding the 🔴 section. Closes the last scenario where the user had to remember to ask "что мне проверить" after an autonomous run — inside the task cycle the handoff was already built in, outside devflow the standalone skill auto-invokes on intent.

## 0.22.2 — 2026-07-02

- **session-digest: conditional state lines** — the digest gains two lines that print ONLY when actionable: an unfinished ralph TODO (`N unchecked, M blocked — ralph-build continues; blocked items need the user`) and unconfirmed manifest markers (`N UNVERIFIED, M TODO — /devflow:revalidate`). Rationale: started large work and unsettled settings were invisible at session start until asked; and a line that appears only when something needs attention gets read, while an always-on line gets skimmed — so the unconditional part stays at exactly 3 lines, and a clean project adds nothing. Deliberately NOT added: env/auth/test commands and tracker details (skills read the manifest on demand — a context copy would drift from the file), git status (the harness already provides it), code style (CLAUDE.md's job).

## 0.22.1 — 2026-07-02

First execution of `tests/INIT-CHECKLIST.md` (react-vite + monorepo-mix, scripted subagent dry-runs): **both fixtures PASS every criterion** — correct type detection (incl. the monorepo one-root-manifest rules), no irrelevant interview questions, honest `# UNVERIFIED` on every unproven claim, clean machine-truth scan, correct INIT.md lifecycle. The runs surfaced 7 friction points in the init skill text (4 found independently by both agents); all fixed:

- **Step 4/5 ordering contradiction removed**: step 4 now *drafts* the manifest, step 5 reviews and *writes* — "generate, then 'before writing present a table'" was unfollowable as numbered.
- **Protected-surface question added to the interview**: the `# none` marker's condition said "exploration + interview establish…", but the interview had no auth question — the condition was unsatisfiable through the listed questions. Now asked explicitly (confirm exploration's finding, not open-ended).
- **Missing CLAUDE.md case specified**: create a minimal one with ONLY the devflow section, recommend built-in `/init` for the rest (was ambiguous between "write now" and "skip entirely").
- **Deferred Tier-2 gaps persist**: postponed gap plans are recorded in `ralph.todo` before INIT.md is deleted — they used to die with the progress file, the exact knowledge loss it exists to prevent.
- **`# UNVERIFIED` scope clarified**: covers every claim not proven live — health URLs and framework-default ports included, not just command fields.
- **Overlay ignore entry is unconditional**: `.devflow/project.local.yml` gets its ignore entry even when the overlay is empty today — it was mandated only inside the related-repos rule, leaving a future overlay one forgotten entry from being committed.
- Empty git history → git-flow questions go open-ended with proposed defaults (nothing to "confirm" on a young repo); template: a foreground-only dev server legitimately has `down: ""` with a comment.

## 0.22.0 — 2026-07-02

- **guard: uncommitted work is not disposable** (Guard 5): `git reset --hard` and forced `git clean` (`-f`/`--force`, any flag cluster) are blocked in devflow projects — the working-tree analog of the volume policy, same `DEVFLOW_ALLOW=1` escape on explicit user request. Soft/mixed resets and `git clean -n` dry runs pass. 9 new regression cases (43 total).
- **doctor full: remote base-branch protection** — the local guard is a floor on this machine; doctor now checks the server-side wall: GitHub (`gh api …/branches/<base>/protection`) or GitLab (`glab`), recommending protection when absent; no CLI/permission/other remote → honestly skipped, never guessed.
- **ralph-build: blocked items must not rot** — when the loop stops on blockers, each `## Blocked` item is offered to `/devflow:issue` (the recorded question + what the iteration learned is the finding), filed keys noted back into the TODO; without a tracker the final report lists them as the user's decision queue.
- Deferred by choice: `on_done: pr` (auto-created MRs) — later; Windows hooks — later.

## 0.21.0 — 2026-07-02

Anti-drift and self-checking: conventions in context from token zero, live validation on demand, the plugin lints itself.

- **New SessionStart hook `session-digest.sh`**: every session opened in a devflow project starts with the load-bearing manifest facts in context — base branch (and that history on it is hook-guarded), branch/commit patterns, the persistent-data policy. Skills reload their rules only when invoked; the digest pins the core conventions between invocations — deterministic, fail-open, silent outside devflow projects. Covered by `tests/session-digest.test.sh`.
- **New skill `/devflow:revalidate [section]`**: init's mandatory live validation, runnable on demand — executes every filled command-like field (env.up + health, auth recipes, tests on confirmation, `db.snapshot`, service host ports) and updates markers in place: pass → `# VERIFIED <date>`, fail → `# UNVERIFIED — reason` with the value kept (fixing values is an approved follow-up, never a silent rewrite mid-validation). `db.restore` is never executed. Division of labor stated: doctor is read-only and finds; revalidate executes and records. Precondition budget applies (~10 tool calls per field). Doctor and config now point their UNVERIFIED listings at it.
- **Plugin self-lint `tests/lint.test.sh`** (runs in CI via `tests/run.sh`): skill/agent frontmatter complete, hooks.json commands exist and are executable (0.9.1's exec-bit regression is now caught mechanically), `${CLAUDE_SKILL_DIR}` references resolve (0.18.1's dangling-path class), the manifest template parses as YAML, keys the hooks grep-parse (`base_branch`, `branch_pattern`, `commit_pattern`, `todo`, `footprint`) stay unique in the template, and plugin.json's version matches the latest CHANGELOG entry.

## 0.20.0 — 2026-07-02

Analysis-driven release: the hook suite becomes committed and CI-enforced, base-branch protection covers all local routes, review skills read the canonical REVIEW.md, committed files get a personal-data floor, docs sync learns Confluence, init gets fixtures and a monorepo story.

- **Committed regression suite + CI**: `tests/guard.test.sh` (34 cases) + `tests/stop-gate.test.sh` (6 cases) — the 0.12.0/0.18.1 adversarial cases plus the new guards, dangerous strings assembled at runtime, disposable sandboxes. `.github/workflows/ci.yml` runs shellcheck + the suite + JSON manifest validation on every push/PR. Doctor's layer-1 self-tests now run this suite (manual probes remain as the pre-0.20 fallback). The 0.18.1 "regression suite green" existed only in that session's context — now it's in git.
- **guard: pushes and merges into base blocked** (Guards 3–4): explicit refspecs targeting base (`push origin <base>`, `HEAD:<base>`, `feature:<base>`, `:<base>` deletion, `--delete <base>`) — checked textually, works outside a repo; bare `git push` while ON base; `git merge`/`git cherry-pick` while ON base. `git pull` on base stays allowed (the sanctioned base update; known limit: `git pull origin <feature>` slips past). Fail-safe trade-off: pushing another ref while standing on base is also blocked — `DEVFLOW_ALLOW=1` covers the legitimate case. Shared helpers (`git_cmd_re`, `git_target_branch`) dedupe the `-C`-aware anchor logic Guard 2 already had.
- **REVIEW.md is part of the review rubric**: the built-in code-review reads repo-root `REVIEW.md` as its highest-priority instructions (severity, nit caps, skip rules, repo checks) — devflow's review loop and task's review step now load it explicitly alongside CLAUDE.md, findings may cite it, its skip rules apply to triage. init mentions it as the canonical place for custom review rules (mention, don't author); GUIDE's rules-layer table gets the row.
- **Machine-truth scan** (doctor layer 2 + init validation rule): committed devflow files (`project.yml`, `.claude/settings.json`, CLAUDE.md section) are scanned for machine/person-specific values — absolute home paths, `$HOME`, the local username, personal email. Hit → move to `project.local.yml` / `settings.local.json`. The related_repos identity/path split generalized: it applies to every committed field (env/test/db/auth commands, permission allowlists), prefer repo-relative commands. Complements the secret scan: secrets were covered, personal data wasn't.
- **Confluence sync** (optional, via the same Atlassian MCP as Jira): `docs.map` entries may carry a `confluence` page (`{ file: …, confluence: <id|url> }`), site/space in `docs.confluence`, asked during init when the tracker is Jira. task's knowledge-sync proposes page updates for touched flows; sync-docs audits mapped pages claim-by-claim and author mode can publish (Confluence stays in the main session — subagents have no MCP tools). All page mutations are outward-facing: draft → approval, never allowlisted (init rule + doctor check extended), updates stamped with the commit ref, MCP-unavailable reported as skipped — never as accurate.
- **Init verification fixtures**: `tests/fixtures/` — six skeleton repos (dotnet-webapi, react-vite, flutter-app, angular-app, terraform-infra, monorepo-mix) + `tests/INIT-CHECKLIST.md` with per-fixture expected type/fields/questions and pass criteria (incl. "no UNVERIFIED markers on a fixture = hallucinated validation = failed check"). Run after changes to the init skill or the template.
- **Monorepo (`type: mixed`) story**: init identifies packages/areas first (workspaces, nx/turbo/melos, solutions), explores each per its own type; ONE manifest at the repo root — whole-stack `env.up`, all HTTP surfaces in `services`, aggregate `test.run` with per-package commands in comments; genuinely independent areas → suggest onboarding a subdirectory as its own project. Template documents the shape.
- **Confirmed absence beats ambiguous emptiness — `# none` marker for auth**: `recipe: ""` could mean "no protected surface" (configuration) or "nobody filled it" (gap) — indistinguishable, against the manifest's own verified-vs-unverified ethos. Now init writes `recipe: ""  # none — no protected surface` once the answer is confirmed; config renders "none (confirmed)" vs "not configured (never asked or deferred)"; doctor: marker = ✓, bare empty + HTTP services listed → suggest settling it; test-flow/api-tester: marker → skip auth confidently, no marker + a 401/403 → reported as a manifest gap, never improvised around.
- Windows support explicitly out of scope for now (hooks are bash) — revisit later.

## 0.19.1 — 2026-06-12

First field run of `/devflow:research` (3 subagents, 26–40 tool calls each, ~175k tokens) — quality was right, the spend was uninformed consent. Searches dominate research cost regardless of model/effort, so depth becomes an explicit, user-controlled lever:

- **Cost gate before fan-out**: 3+ angles → the skill announces the plan (angles, subagent count, that this is the ~100–200k-token path) and asks full vs quick before spawning. Single-angle questions skip the gate.
- **Subagent budget ~15 tool calls** (precondition-budget pattern): budget spent → synthesize from what was gathered and name what stayed uncovered; return compressed sourced conclusions, never page retellings.
- **`quick` mode** (`/devflow:research quick <q>`): inline, no subagents, ~8–10 searches, contrarian pass shrunk to one query — and therefore every finding must carry its honest (mostly weaker) confidence grade. For low-stakes questions, never for irreversible decisions; full stays the default.

## 0.19.0 — 2026-06-12

The human's bottleneck is verifying agent work, not producing it — handoffs now spend the reviewer's attention where the risk is. Practices borrowed from fields where the reviewer's miss is expensive: risk-based audit sampling (review effort proportional to risk), structured medical handoffs (fixed sections make omission visible), and the two-minute verifiability rule.

- **New skill `/devflow:handoff`** — the format authority: 🔴 judgment calls + auto-red changes (migrations, auth, data mutation, contracts, concurrency — classified by closed rules, not self-assessment) / 🟡 derived-never-executed / 🟢 mechanical as a count / "verify in 2 minutes" with commands actually run and their observed outputs. All sections always present (empty = one honest line); honest limit stated: only the re-checks are falsifiable, the rest is self-assessment by the model that did the work. Standalone use covers work done without devflow skills or by another agent (then judgment calls are reconstructed from the diff and flagged as weaker).
- **task**: close-the-loop presentation renders as a review handoff (format referenced from the handoff skill, not duplicated).
- **ralph-build**: TODO result notes must record forks — `⚠ judgment call: chose X over Y`; after an autonomous run, `grep ⚠` over the TODO surfaces every decision the loop took without the user.
- **test-flow / api-tester**: verification depth per step (response shape / status code only / side effects) — a status-only ✅ must declare itself; test-flow also names scenario-mapping interpretation choices.
- Not touched by design: sync (✅/🔧/❓ classification already is an attention map), research (confidence grades already are the handoff), review (triage already surfaces judgment calls), doctor/config/init/issue (deterministic or gated — a handoff block there is ritual noise).

## 0.18.1 — 2026-06-12

Second cold adversarial review (10 findings, all with reproductions) — all addressed:

- **guard coverage**: `docker system prune --volumes` and `docker compose rm -v` (any flag cluster) now blocked; `git -c k=v commit` no longer slips past the base-branch guard (interleaved `-c`/`-C` runtime options matched); `DEVFLOW_ALLOW=1` works with leading whitespace. Full regression suite green (15 cases, incl. no-overmatch checks).
- **`${CLAUDE_PLUGIN_ROOT}` in skill bodies** replaced with `${CLAUDE_SKILL_DIR}/../..` — the former is substituted in hooks.json but not in skill content; skills relied on model improvisation to find the plugin root (worked in practice, was not deterministic).
- **secret scan mechanics**: detect with `grep -lE` / `grep -nE … | cut -d: -f1`, never bare `grep -n` (whose output echoes the secret); pattern list extended (connection strings with inline passwords, private key blocks) and marked non-exhaustive — doctor and sync-docs aligned.
- **footprint:local seam closed**: the overlay's ignore entry goes to `.git/info/exclude` in local mode, never a committed `.gitignore` line.
- test-flow: numbering fixed, precondition budget now explicit on the inline (non-HTTP) path too.
- **honest limits told fully** (README + guard header): multi-line commands and state-changing compound commands (`checkout main && commit`) are past the floor; dangerous literals in harmless arguments block safely; "physically prevented" softened to "deterministic guard". Accepted as designed: the false-positive trade-off (doctor's registration test depends on it); no DEVFLOW_ALLOW hint added to block messages — the bypass stays user-initiated only.

## 0.18.0 — 2026-06-12

Lessons from a long-running session: preconditions get budgets, drafts get a deterministic floor.

- **Precondition budget in test-flow / api-tester**: environment, auth, and fixture data are preconditions, not the mission — ~10 tool calls of honest effort, then STOP and report the gap as a finding (broken recipe step, missing fixture, manifest gap) with what would fix it. An hour of auth archaeology is a failed run even if a token eventually appears. The manifest recipe is the ONLY auth path tried — no exploring alternative grants. Stale-binary awareness: a green step against an old build is a false verdict.
- **`auth.user_recipe`** in the template: optional second recipe for a token AS A SPECIFIC USER (authorization_code/PKCE, form login, seed account) — for identity-dependent flows (ownership, role-gated transitions) when the main recipe is service-level. Empty + flow needs it → manifest gap, derive it with the user.
- **Tracker mutations never allowlisted** (init permissions rule + doctor check): skills are advisory and long sessions drift past them — a real session created a Jira issue with no draft shown, bypassing the issue skill entirely. The permission prompt on an un-allowlisted create/edit/transition/comment/link call is the deterministic "show the payload, ask first" floor; doctor flags such tools in allowlists, read-only tracker tools remain fine. Known limit: permissive session modes (auto-approve) trade this floor away.
- test-flow: fixture preconditions checked before execution; missing test data → options (seed / API setup / targeted edit), chosen with the user.

## 0.17.2 — 2026-06-12

- sync-docs author mode: un-ignoring must never widen exposure. When an ignore rule is removed so mapped docs can be committed, every file it was protecting that stays local gets its own targeted ignore entry in the same edit, verified per file with `git check-ignore`. (Field run removed a whole-directory ignore and left a credential-bearing doc merely untracked — one `git add -A` away from a leak.)

## 0.17.1 — 2026-06-12

- sync-docs author mode: git status of a doc is determined PER FILE (`git ls-files --error-unmatch`, then `git check-ignore`), never generalized from a directory listing — first field run declared 9 docs "all committed" when 6 of them were gitignored and invisible to every clone. Plus a mandatory secret scan before any doc is mapped or proposed for commit: a hit excludes the file until cleaned, reported by location only (the same run nearly proposed committing docs with live connection-string passwords).

## 0.17.0 — 2026-06-12

Docs become a guaranteed knowledge layer: devflow now ensures mapped docs exist and are team truth, not just audits them when they happen to be there.

- **sync-docs author mode**: empty `docs.map` (or mapped files missing) → inventory existing docs (classifying contract / reference / personal note, checking git status of each), propose a map that keeps the project's own names and locations, and for gaps generate a canonical skeleton shaped by `project.type` (architecture / environments / contracts / testing) — written FROM CODE with the same claim-by-claim discipline as auditing, as ordinary committed project files. No invented content, no devflow-private formats.
- **Team-truth rule for mapped docs** (doctor): every `docs.map` file must exist and be git-tracked — an untracked or gitignored mapped doc is one person's notes that teammates never see. `footprint: local` exempt by design.
- init step 8: propose the map from docs found during exploration (tracked contracts only), point to author mode when there's nothing usable; never blocks init.

## 0.16.0 — 2026-06-12

Machine-local overlay: team truth and machine truth no longer share a file.

- **New `.devflow/project.local.yml`** — sparse overlay with the same structure as the manifest, gitignored, overlaid on top (local wins). For values true only on one computer; the committed manifest stays valid for every teammate.
- **`related_repos` split**: identity (`url`, `branch`, `relationship`) is committed; the absolute local `path` lives in the overlay under the same key. An absolute path in a committed manifest was a bug waiting for the second contributor. Solo projects may still keep `path` in the manifest.
- sync resolves the path overlay-first, asks once if missing and writes the answer to the overlay (never the manifest), offers to clone from `url` when the repo isn't on this machine.
- config renders overlay values marked `(local)`; doctor treats "identity present, not cloned here" as ℹ, and flags a committed `path` in a multi-contributor repo.
- init writes paths to the overlay from the start and adds the `.gitignore` entry.

## 0.15.3 — 2026-06-12

- doctor: mandatory secret scan in layer 2 — manifest and `.claude/settings*.json` checked for credential patterns (Atlassian/GitHub/GitLab/AWS tokens, basic-auth in curl, literal Bearer). A hit is ✗ critical with a revocation demand: a secret that sat in plaintext is compromised, deleting the line is not enough. The secret itself is never printed, not even a prefix — pattern name and location only. (The check existed only as model improvisation — it caught a live token in the wild; now it's deterministic protocol.)

## 0.15.2 — 2026-06-12

- issue skill: no area/type prefixes in issue titles (`[BACKEND]`, `МОБА:`, `Bug:` …) — routing lives in `tracker.labels` and the issue type; a title prefix duplicates them and pollutes search and boards.
- config skill: auth verification status is read from the manifest's `# UNVERIFIED` markers, never invented from session state — config is a viewer of recorded facts, and "not run in this session" is not UNVERIFIED (it would mark every validated recipe stale in every fresh session).
- template: `services.*.port` is explicitly the HOST port. A service behind a gateway with no host mapping (compose `expose`, k8s ClusterIP) records `port: ""` plus the gateway route in a comment — never the container-internal port (found in the wild: init recorded a container's `:80` as a host port, sending agents to the gateway instead).

## 0.15.1 — 2026-06-12

- issue skill: relations become REAL tracker links ("link, don't mention"). Related issues are listed in the draft with a proposed link type, created via the tracker's link mechanism right after filing (Jira `createIssueLink`, GitHub cross-reference, Linear relation), and reported; a failed link is said out loud, never silently dropped. A textual "related to ABC-12" is prose — boards, filters, and automation only see links.

## 0.15.0 — 2026-06-12

Init can no longer die halfway. An abandoned onboarding was the most common path to a half-configured project — nothing surfaced it.

- **init progress lives in `.devflow/INIT.md`** (same file-based-progress pattern ralph uses for its TODO): created as the first action, steps checked off as they complete, deleted only when live validation passes or is explicitly deferred with `# UNVERIFIED` markers.
- **New SessionStart hook `init-reminder.sh`**: a session opened in a project with a surviving INIT.md gets one deterministic context line — init is unfinished, resume with `/devflow:init`. Fail-open, never blocks, silent everywhere else.
- **Resume instead of STOP**: re-init protection now distinguishes "configured project" (manifest, no INIT.md → STOP as before) from "unfinished init" (manifest + INIT.md → continue from the first unchecked step, keep earlier answers).
- **Drift rule in init**: if the user diverts mid-init, help them, then steer back to the checklist; stopping for real is allowed but said out loud.
- doctor (layer 2) and config both report a surviving INIT.md as unfinished init; doctor layer 1 checks the new hook file.

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
