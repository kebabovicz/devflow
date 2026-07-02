---
description: Re-run init's live validation on the existing manifest — execute every command-like field (env, auth, tests, services) against reality and update the # UNVERIFIED / # VERIFIED markers to match. Use when the manifest may have drifted, after environment or infra changes, or to clear UNVERIFIED homework left by a deferred init.
disable-model-invocation: true
---

# devflow revalidate: $ARGUMENTS

Read `.devflow/project.yml`, overlay `.devflow/project.local.yml` if present. No manifest → stop: the project isn't onboarded, point to `/devflow:init`.

This is init's "mandatory live validation" step, runnable on demand. Division of labor: **doctor is read-only and finds problems; revalidate executes and records the outcome in the manifest's markers.** A manifest nobody has executed recently is a hypothesis — this skill turns it back into a manifest.

## Scope

"$ARGUMENTS" names sections (`env`, `auth`, `test`, `db`, `services`) → validate only those. Empty → every command-like field that is filled. Empty optional sections are configuration, not gaps — skip them silently; `auth.recipe: ""` with a `# none` marker validates as nothing (confirmed public surface).

## Protocol

1. Execute each in-scope field the way init's live validation does:
   - `env.up` → run it, poll `env.health` until green (on failure report the last health response). If the environment is already up and healthy, that counts — don't restart it;
   - `auth.recipe` / `auth.user_recipe` → execute the steps, confirm real authenticated access (never print the token);
   - `test.run` / `test.integration` → ask before running (suites can be slow), report green/red;
   - `db.snapshot` → safe to execute; `db.restore` is destructive — NEVER execute it, it stays a derived claim;
   - `services.*.port` → the recorded HOST port actually answers.
2. **Update markers in place, nothing else**: a field that passed → remove `# UNVERIFIED`, set `# VERIFIED <YYYY-MM-DD>`; a field that failed → `# UNVERIFIED — <one-line reason>`, keeping the recorded value untouched. Fixing a wrong value is a follow-up the user approves (small: edit + re-run this skill; structural: `/devflow:task`) — never a silent rewrite during validation.
3. **Precondition budget** (test-flow's rule): ~10 tool calls of honest effort per field, then record the failure and move on — revalidate reports reality, it does not debug the environment.
4. Tear down only what you started; an environment that was already running stays running.

## Report

Table: field → what was executed → result → marker change. Close with VERIFIED/UNVERIFIED counts; for each UNVERIFIED give the one-line reason and the likely fix path (manifest edit / environment fix / a Tier-2 gap → `/devflow:task`).
