---
description: Decision map for a piece of work — carries it from a raw idea to ready implementation tickets through the stages the work actually has: recon, requirements, concept, spec, detailed design, slicing. Decisions live in files that outlive the session, so nothing is silently decided by whoever implements. Use when starting anything past a one-line fix.
disable-model-invocation: true
---

# Map: $ARGUMENTS

**Read `${CLAUDE_SKILL_DIR}/../OUTPUT-STYLE.md` before your first message and follow it** — it binds every message this skill prints and every file it writes for a person to read.

An idea arrives and the way from here to a built feature is not visible yet. This skill charts that way as a **map of decisions** — files that outlive the session — and works it one decision at a time, until nothing is left to decide and the work can be cut into tickets.

**Decide, don't build.** Every stage here produces decisions; code comes after the map closes, from `/devflow:task`. The pull to "it's clear enough, let me just build it" is the exact failure this skill exists to stop — a decision nobody made is a decision the implementing agent makes silently.

## Where it lives

Read `.devflow/project.yml` → `maps.dir` (default `.devflow/maps`); no manifest → use the default and say so, the map needs nothing else from it.

```
<maps.dir>/<kebab-slug>/
  map.md              the index — loaded once per session
  issues/NN-slug.md   decision tickets
  spec.md             stage: specification
  design.md           stage: detailed design
  tickets/NN-slug.md  implementation tickets — what /devflow:task takes
```

**Maps are never versioned.** Before writing the first file, ensure `<maps.dir>/` is listed in `.git/info/exclude` — add it if absent. Never `.gitignore`: that file is itself committed, and a planning draft is the user's thinking, not the team's documentation. This holds at every `project.footprint` value, `committed` included.

Formats: `${CLAUDE_SKILL_DIR}/MAP-FORMAT.md` for the map and its decision tickets, `${CLAUDE_SKILL_DIR}/DESIGN-FORMAT.md` for the spec and the detailed design, `${CLAUDE_SKILL_DIR}/SLICING.md` for cutting implementation tickets.

## Two modes

Pick by what exists: no map for "$ARGUMENTS" → **chart** it; a map exists (by slug, path, or the only open one) → **work** it. Several open maps and an ambiguous argument → list them and ask.

### Chart

1. **Recon first.** Before a single question, find out how the affected area works today: the flows, the extension points, the traps. This is the recon stage, and it is the agent's job — never the user's. Write what you found into the map's *How it works today* section. A question the repo already answers burns the user's patience and their trust in the questions that matter.
2. **Name the destination.** What reaching the end of this map looks like — a built feature, a decision locked, a migration done. The destination fixes the scope, so it is settled first: everything past it is out of scope, and the fog only ever gathers toward it.
3. **Map the frontier — breadth first.** Fan out across the whole space rather than deep on one thread, surfacing the decisions this work hangs on. Call `${CLAUDE_SKILL_DIR}/../discuss/SKILL.md` for the interview discipline — including its rule that a vague qualifier (*suitable*, *simple*, *standard*) is a question, never a value you fill in yourself.
4. **Create the map**, then the tickets you can already state sharply, then wire their `Blocked by` edges in a second pass. What you cannot state sharply yet goes to *Not yet specified* — do not pre-slice fog into ticket-sized pieces.
5. **Fire the research tickets** — every `research` ticket can be resolved in parallel by subagents right now, since none of them needs the user. Then stop: charting is one session's work and resolves nothing by hand.

**Small ideas get small maps.** Two tickets and a one-paragraph destination is a valid map, chartable and closeable in one sitting. The ritual scales down; skipping it does not.

### Work

1. **Load the map** — the index, not every ticket body. Zoom into a ticket only when you need its detail.
2. **Take the first frontier ticket** (open, unblocked, unclaimed) unless the user named one. Claim it — set `Status: claimed` before any work, so a parallel session skips it.
3. **Resolve it by type**: `research` → `${CLAUDE_SKILL_DIR}/../research/SKILL.md`, resolved by the agent alone; `grilling` → `${CLAUDE_SKILL_DIR}/../discuss/SKILL.md`, resolved by live conversation with the user. **On a grilling ticket the agent never answers for the user** — an unanswered question goes back to the map, it never gets a silently-picked answer.
4. **Record the resolution**: the answer under `## Answer` in the ticket, `Status: resolved`, and one gist line with a link in the map's *Decisions* section. The detail lives in the ticket; the map only points at it.
5. **Clear the fog the answer lifted**: graduate whatever is now sharp into new tickets (create, then wire edges), removing that patch from *Not yet specified*. If the answer puts a ticket past the destination, close it and leave one line in *Out of scope* — a scope boundary is not a step on the route. If it invalidates other tickets, update or delete them.
6. **One decision per session is the recommendation** — a fresh window decides better than a crowded one. Continue if the user wants; `research` tickets are exempt, they cost the user nothing.

**Stopping mid-effort** — the map already carries the decisions, but not what the current session learned while working one. Write a work handoff (per `${CLAUDE_SKILL_DIR}/../handoff/SKILL.md`): into the ticket if one is open, into `HANDOFF.md` if the whole effort is being parked.

## Closing the map — the three outputs

When the frontier is empty and no fog remains, the map stops being a question list and becomes three artifacts, in order. Formats in `DESIGN-FORMAT.md` and `SLICING.md`.

1. **`spec.md`** — what and why: problem, solution, user scenarios, done-criteria, out of scope. No implementation detail here.
2. **`design.md`** — how exactly: interfaces and seams, data shapes and contracts, behavior at the edges, rejected alternatives. This is the document that stops the implementing agent from inventing; every question it leaves open, someone else will answer silently.
3. **`tickets/`** — vertical slices with `Blocked by` edges and acceptance checklists, worked frontier-first by `/devflow:task <path>`.

**Tracker is optional, and offered last.** With `tracker.system` configured, offer once to publish the implementation tickets as issues; on approval, record each returned key next to its local ticket. The local file stays the source of truth — a project without a tracker loses nothing here.

## Closing the effort — archive, having carried the knowledge out

When every implementation ticket is `done`, the effort is over and its directory stops earning its place in `<maps.dir>/`. Two steps, in this order:

1. **Carry out what outlives the effort.** The map holds knowledge that dies with it otherwise — present each candidate and let the user decide: *rejected alternatives* from `design.md` (the reason a future session will not re-invent the losing option), *sharpened terms* from the decisions, *how it works today* once the change has made it stale or newly true. Their homes are the project's own docs — `docs.map` entries, an ADR, the project CLAUDE.md — never the archive. **Do this before archiving, never after**: an archived effort is out of sight, and out of sight is where knowledge goes to die.
2. **Archive the directory**: move `<maps.dir>/<effort>/` to `<maps.dir>/.done/<effort>/`. Same git exclusion (the whole map directory is excluded), out of the session digest, still on disk if the reasoning is ever needed again. Deleting outright is the user's call, not the default — the cost of keeping it is one directory nobody looks at.

## Rules

- **The map is an index, not a store.** A decision lives in exactly one place — its ticket. The map gists it and links; restating it there creates two versions that drift.
- **Fog is deliberate.** Chart only what you can state sharply *now* — the test is whether you can phrase the question, not whether you can answer it. A blocked ticket you can phrase is a ticket; a question you cannot phrase yet is fog.
- **No implementation, no file edits outside `<maps.dir>/`.** Recon reads code; it does not change it.
- **Every ticket carries its type and its edges** — an unlabeled ticket cannot be routed, an unwired one breaks the frontier.
- Re-running on an existing map continues it; it never starts over.
