---
description: Audit project docs against the actual code and fix drift — checks every doc in the manifest docs.map for statements the code contradicts. Use when asked to check or update documentation, or after a flow changed. Add 'swarm' to run the audit as a verified Workflow pipeline that independently confirms each claimed code bug.
---

# Sync docs

Read `.devflow/project.yml` → `docs.map`. No manifest → stop: the project isn't onboarded, point to `/devflow:init`. Empty map → enter **author mode** (below) instead of auditing nothing.

## Author mode — when the map is empty or mapped files don't exist

devflow guarantees mapped docs exist and don't lie; when they don't exist yet, it creates them — as ordinary committed project files the team can edit without devflow, never a devflow-private format. What it will not create is a document restating the API surface: that one is stale the day after it is written, and the code already answers it.

1. **Inventory what's already written**: doc files in the repo (root `*.md`, `docs/`, wiki dirs). Classify: flow contract (describes what the system does — mappable) / reference (troubleshooting, tech-debt registers, one-off migration guides — useful but not mappable) / personal note. **Git status is determined PER FILE — never generalized from a directory listing**: `git ls-files --error-unmatch <file>` → tracked; else `git check-ignore <file>` → ignored; else untracked. (Beware: `check-ignore` is silent about tracked files even when a pattern matches them, and a non-empty `ls-files <dir>` proves nothing about the files it didn't list.) The classification table gets a git column (tracked / ignored / untracked); an untracked or ignored "doc" is one person's notes, not team documentation — say so. **Scan every doc you intend to map or commit for secrets** (credential patterns, connection strings with passwords, key material — doctor's pattern list, treated as non-exhaustive): a hit excludes the file from both the map and any commit proposal until the user cleans it — and gets reported like doctor reports it (location only, never the value; detect with `grep -lE` / `grep -nE … | cut -d: -f1`, never bare `grep -n`).
2. **Propose the map**: existing docs keep their names and locations — devflow adapts to the project, not the reverse. For gaps, propose a canonical skeleton shaped by `project.type` (universal names, content per type): `architecture` (services/modules topology), `environments` (local/staging/prod, config), `testing` (how to verify). Only what the type warrants — a library doesn't need an environments doc.
   **Never propose an API-surface document** — an endpoint list, a DTO catalogue, a CLI reference. It is the fastest-rotting document a project can own: every change to a route or a field silently invalidates it, and the cost of keeping it true is paid forever by whoever forgets. That surface is already answered live by the code and by the schema in `services.<name>.schema`, so the honest instruction is to read it there. An API doc the team already wrote and mapped is still audited like any other — devflow stops creating this one, it does not delete what exists.
3. **Generate from code, on approval**: each new doc is written from what the code actually does (same claim-by-claim discipline as auditing, in reverse). No invented content: a section the code can't substantiate stays out. Write the map into `.devflow/project.yml → docs.map`.
4. **Team truth**: new docs and newly mapped docs must be git-trackable — if a doc the user wants mapped is gitignored/untracked, surface it and propose committing it (audit it first if it predates devflow). Exception: `footprint: local` — there everything stays untracked by design.
5. **Un-ignoring must never widen exposure**: when an ignore rule (e.g. a whole `docs/` line) has to go so mapped docs can be committed, every file that rule was protecting and that stays local gets its own targeted ignore entry IN THE SAME EDIT — a secret-bearing or personal file left merely untracked is one `git add -A` away from a leak. Verify with `git check-ignore` per remaining file before reporting done.

## Protocol

1. **Scope**: if the user named a flow/area (in "$ARGUMENTS" or conversation), audit only its mapped docs; otherwise audit the full map **plus the knowledge artifacts agents depend on**: `.devflow/project.yml` (ports, services, auth, env claims) and project CLAUDE.md (patterns, repository map).
2. **Full audits run as a parallel fan-out** — one agent grinding the whole map serially takes tens of minutes:
   - partition the docs into 3–4 buckets by area (related docs together — they share the code they're checked against); manifest + CLAUDE.md form their own bucket, so no two agents ever touch the same file;
   - spawn one `docs-sync` agent per bucket **in parallel — all Agent calls in one message**; each agent edits only its bucket's files (no overlap by construction);
   - **offer background execution** (`run_in_background`) so the user keeps working in the session; report when all buckets land;
   - **aggregate**: merge per-bucket reports into one classification table and one deduplicated 🐛 findings list — the user gets a single digest, never N raw reports.
   Small scopes (≤3 docs) stay in a single agent — fan-out overhead isn't worth it.
3. **Confluence pages are part of the map**: a `docs.map` entry with a `confluence` page (see `docs.confluence` in the manifest) is audited claim-by-claim like a file — fetch the page via the Atlassian MCP, verify its statements against the code. **Confluence stays in the main session, never in a docs-sync subagent** (subagents have no MCP tools). Edits are outward-facing: show the draft, apply only on approval, stamp with the commit/ref the update reflects. MCP unavailable or unauthenticated → report those pages as skipped with a `/mcp` pointer — never as accurate. Author mode: when `docs.confluence.site` is configured, offer publishing new/mapped docs as pages in `docs.confluence.space` — same approval gate.
4. **Verify claim by claim**: for each doc, check every concrete statement (endpoints, statuses, field names, sequence of steps, config keys) against the code. Code is the source of truth for *what is*; the doc may still be right about *what should be* — when behavior and doc disagree, classify: stale doc vs actual bug.
5. **Report**: per doc — ✅ accurate / 📝 stale (with the exact outdated claims) / 🐛 doc reveals a code bug.
6. **Fix stale docs** on approval: minimal edits, preserve the doc's structure and language. Bugs go to the user (or to `/devflow:map`), never silently "fixed" by rewriting the doc to match broken behavior.

## Swarm mode (`swarm` — verified Workflow pipeline, opt-in)

The bucket fan-out in step 2 already parallelizes; `swarm` as a word in "$ARGUMENTS" (when the Workflow tool is available) makes it a deterministic pipeline and adds the verification gate the plain fan-out lacks. No Workflow tool → the Agent-based fan-out in step 2 stands as-is; say so.

- **Bucket audit → finding verification, per bucket, no barrier**: as each bucket agent returns, every 🐛 (doc reveals a code bug) it claims is handed to a second, independent agent that re-checks the claim against the code before it reaches the digest — a "bug" no verifier can substantiate is downgraded to a 📝 stale-doc note or dropped, with a line saying so. 📝 stale-doc edits don't need this gate.
- **Partitioning is unchanged**: 3–4 area buckets, manifest + CLAUDE.md their own bucket, no two agents touching the same file — so parallel edits never collide.
- **Confluence still stays in the main session** — verify its pages after the swarm returns, never inside a Workflow agent.
- **Aggregate exactly as step 2 requires**: one classification table, one deduplicated 🐛 list — the user gets a single digest, and the same approval gate governs any edit.
