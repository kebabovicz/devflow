---
description: Audit project docs against the actual code and fix drift — checks every doc in the manifest docs.map for statements the code contradicts. Use when asked to check or update documentation, or after a flow changed.
---

# Sync docs

Read `.devflow/project.yml` → `docs.map`. No manifest → stop: the project isn't onboarded, point to `/devflow:init`. Empty map → propose one by matching existing doc files to code areas, then proceed.

## Protocol

1. **Scope**: if the user named a flow/area (in "$ARGUMENTS" or conversation), audit only its mapped docs; otherwise audit the full map **plus the knowledge artifacts agents depend on**: `.devflow/project.yml` (ports, services, auth, env claims) and project CLAUDE.md (patterns, repository map).
2. **Full audits run as a parallel fan-out** — one agent grinding the whole map serially takes tens of minutes:
   - partition the docs into 3–4 buckets by area (related docs together — they share the code they're checked against); manifest + CLAUDE.md form their own bucket, so no two agents ever touch the same file;
   - spawn one `docs-sync` agent per bucket **in parallel — all Agent calls in one message**; each agent edits only its bucket's files (no overlap by construction);
   - **offer background execution** (`run_in_background`) so the user keeps working in the session; report when all buckets land;
   - **aggregate**: merge per-bucket reports into one classification table and one deduplicated 🐛 findings list — the user gets a single digest, never N raw reports.
   Small scopes (≤3 docs) stay in a single agent — fan-out overhead isn't worth it.
3. **Verify claim by claim**: for each doc, check every concrete statement (endpoints, statuses, field names, sequence of steps, config keys) against the code. Code is the source of truth for *what is*; the doc may still be right about *what should be* — when behavior and doc disagree, classify: stale doc vs actual bug.
4. **Report**: per doc — ✅ accurate / 📝 stale (with the exact outdated claims) / 🐛 doc reveals a code bug.
5. **Fix stale docs** on approval: minimal edits, preserve the doc's structure and language. Bugs go to the user (or to `/devflow:ralph-plan`), never silently "fixed" by rewriting the doc to match broken behavior.
