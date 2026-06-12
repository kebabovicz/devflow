---
description: Diagnose the devflow installation and project — dependencies, guardrail hooks, manifest health, integrations. Use when something doesn't work, after installing or updating the plugin, or on a new machine. Pass "full" to add live checks (running env, auth recipe, tracker).
---

# devflow doctor

Read-only diagnostics: never start/stop the environment, never modify files. For every non-green check output a one-line fix. Levels: default = layers 1-2; "$ARGUMENTS" contains `full` → add layer 3.

## Layer 1 — installation (always)

- Dependencies: `git`, `jq` always; `docker` only if the project's manifest references it (env/db/services) — a frontend or IaC repo without docker is fine. Optional: `claude-squad`/`tmux`/`gh`. **Missing jq = ✗, not a warning**: guardrails fail-open and become silently inactive.
- Plugin files: `${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh`, `${CLAUDE_PLUGIN_ROOT}/hooks/ralph-stop-gate.sh` and `${CLAUDE_PLUGIN_ROOT}/hooks/init-reminder.sh` exist and are executable.
- **Guard script self-test** (proves the script's logic works). IMPORTANT: the test command must NOT contain the dangerous string literally — the session's own guard hook would block the test itself. Assemble it at runtime:
  - `printf '{"tool_input":{"command":"docker volume %s"},"cwd":"%s"}' prune "<project-root>" | guard.sh` → expect exit 2;
  - same with `"$HOME"` as cwd → expect exit 0 (scoping works).
- **Hook REGISTRATION test — the script working is not the hook firing** (a correct script that Claude Code never calls protects nothing). Only meaningful when the session cwd IS a devflow project root (hook scoping uses the session cwd): run a harmless command that contains the dangerous literal — `echo "docker volume prune"` typed literally, the inverse of the assembly trick above. **Expect your own tool call to be BLOCKED by the guard — the block IS the green result.** If the echo goes through, the hooks are not registered in this session: ✗ BROKEN with fix hint (re-run install.sh, restart the session / `/reload-plugins`, check the symlink). Outside a project root, mark this check as skipped — never report hooks healthy on script tests alone.
- **Stop-gate self-test** — both paths, using a disposable sandbox (the project itself is never touched): create `mktemp -d` with `git init`, a minimal `.devflow/project.yml` (`ralph.todo` set) and an uncommitted TODO file → pipe `{"cwd":"<sandbox>","stop_hook_active":false}` → expect exit 2 (dirty blocks); commit the TODO → same pipe → expect exit 0; `"stop_hook_active":true` → always exit 0 (loop protection). Clean up the sandbox.

## Layer 2 — project (when `.devflow/project.yml` exists; otherwise note "not a devflow project" and stop after layer 1)

- **`.devflow/INIT.md` present → ! unfinished init** (init tracks progress there and deletes the file on completion). List its unchecked steps; fix: resume with `/devflow:init`. The manifest may be real but unvalidated — weigh other layer-2 findings accordingly.
- Manifest parses as YAML (`python3 -c "import yaml,sys; yaml.safe_load(open(...))"`; no pyyaml → basic structural check, mark as skipped).
- Expected sections present: `project`, `env`, `auth`, `test`, `git`, `ralph` (missing → suggest `/devflow:update`). **Present-but-empty optional sections (auth, db, services, related_repos, tracker) = "not configured", never a failure** — many project types legitimately don't need them.
- List all `# TODO` and `UNVERIFIED` markers — each is a pending item, not an error.
- Committed permissions: `.claude/settings.json` exists with an allowlist; if permissions live only in gitignored `settings.local.json` → warn (teammates won't get them).
- **Secret scan — mandatory**: grep `.devflow/project.yml`, `.claude/settings.json`, `.claude/settings.local.json` for credential patterns (`ATATT` Atlassian, `ghp_`/`github_pat_` GitHub, `glpat-` GitLab, `AKIA` AWS, `sk-` API keys, `curl -u user:password`, `Bearer <literal>`). Any hit → ✗ critical: name the file and line, demand revocation (a secret that sat in plaintext is compromised — removing the line is not enough), point to the proper channel (MCP OAuth / env vars). **Never print the secret itself — not even a prefix or suffix; show only the pattern name and location.**
- `related_repos` paths exist on disk (resolve via `.devflow/project.local.yml` overlay first, then the manifest). Identity present but no path on this machine → ℹ "not cloned here", never a failure. A `path` inside the *committed* manifest of a multi-contributor repo → ! suggest moving it to the gitignored `project.local.yml`.
- **Mapped docs are team truth**: every file in `docs.map` must exist AND be tracked by git — an untracked or gitignored mapped doc is one person's notes that teammates and fresh clones will never see → ! with fix "commit it (audit first via /devflow:sync-docs) or unmap it". Exception: `footprint: local` — untracked by design, skip the check.
- Working tree on `git.base_branch`? Just informational — flag uncommitted manifest/doc changes.

## Layer 3 — live (`full` only; may take minutes)

- If the manifest uses docker: daemon responds. Which `env.health` checks pass right now (do NOT start the env — report "environment not running" as a fact, not a failure).
- If the environment is up and `auth.recipe` is configured: execute it → authenticated access obtained? (Note: may create a throwaway user — expected by design.)
- `test.run` defined → ask the user before running (can be slow), report green/red.
- Tracker configured → verify its MCP tools are reachable (lightweight call, e.g. fetch one issue); not authenticated → fix-hint `/mcp`.

## Report

One table per layer: check → ✓/!/✗ → fix. Final verdict:
- **HEALTHY** — all ✓ (TODO markers allowed);
- **DEGRADED** — works, but warnings listed;
- **BROKEN** — blockers; name the single most important next action.
