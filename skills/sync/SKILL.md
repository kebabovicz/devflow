---
description: Analyze what changed in a related repository since the last sync and plan matching changes in this one — incremental diff with a remembered baseline. Use when a counterpart repo (frontend, backend, mobile app, shared contracts, infrastructure-as-code) moved and this project must adapt.
disable-model-invocation: true
---

# Sync with related repo: $ARGUMENTS

Read `.devflow/project.yml` → `related_repos`, then overlay `.devflow/project.local.yml` if present (same structure, machine-local values win). No manifest → stop: the project isn't onboarded, point to `/devflow:init`. "$ARGUMENTS" names which one (empty + single entry → use it; empty + several → ask). No `related_repos` configured → ask the user for url/branch/relationship and write it into the manifest.

**Resolving the repo's local path**: overlay `path` → manifest `path` → neither set or the directory doesn't exist on this machine → ask the user once and write the answer to `.devflow/project.local.yml` (NEVER the committed manifest — paths are machine truth, identity is team truth). Make sure the overlay file is gitignored; offer to clone from `url` if the repo isn't on this machine at all.

## Protocol

1. **Load sync state** from `.devflow/sync/<name>.json` (`{ "last_synced_ref": "<sha>" }`). Missing → first sync: ask the user for a baseline ref.
2. **Diff the related repo**: `git -C <path> fetch && git -C <path> diff <last_synced_ref>..origin/<branch>`. What to focus on depends on `relationship`:
   - `consumer` (they call our API): their API usage — endpoints, request/response shapes, query params, auth headers;
   - `provider` (we call their API): their contracts/DTOs, routes, versioning, breaking changes;
   - `sibling` (shared contracts/protos): the shared definitions both depend on.
3. **Map to this repo**: for every relevant change find the local counterpart. Classify: ✅ already compatible / 🔧 change needed here / ❓ intent unclear.
4. **Propose a plan** for the 🔧 items. Discuss; do not implement before approval. Execution goes through the normal flow: `task` for small scope, `ralph-plan` for large.
5. **After the work is done and verified**, update `.devflow/sync/<name>.json` with the new ref.

## Rules

- The related repo is **read-only** for this skill — never edit it.
- The other side is not automatically right: if its change contradicts a documented contract here, surface the conflict instead of silently adapting.
