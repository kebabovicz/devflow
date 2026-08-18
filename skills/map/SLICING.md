# Cutting implementation tickets

The map's last act: turn the spec and the design into work someone can take.

## `tickets/NN-slug.md`

Numbered from `01` in dependency order — blockers first.

```markdown
# NN — <ticket title>

Blocked by: 02, 03        <!-- or: none — can start immediately -->
Status: open | in progress | done
Tracker: ABC-42           <!-- added only after an approved publish -->

## What it delivers

<the end-to-end behavior this ticket makes work, from the user's perspective —
not a layer-by-layer implementation list>

## Acceptance

- [ ] <criterion — mechanically checkable: a test, a command with expected output>
- [ ] <criterion>

## Design

<the sections of design.md this ticket implements — by heading, not copied.
If this slice deliberately departs from a pattern used elsewhere in the
codebase, say so here in one line — the implementer must not "restore
consistency" on their own, and the reviewer must not read it as a slip.>
```

## Vertical slices

Each ticket is a **tracer bullet**: a narrow but complete path through every layer the change touches — schema, service, API, UI, tests — not a horizontal slice of one layer.

- a finished slice is demonstrable or verifiable on its own;
- it fits in one fresh context window;
- prefactoring goes first, in its own ticket: make the change easy, then make the easy change.

A slice that only adds a database column, with nothing reading it, is horizontal — it delivers no behavior and can be verified only by looking at the schema. Fold it into the slice that uses it.

## Wide refactors are the exception

A **wide refactor** is one mechanical change — renaming a column, retyping a shared symbol — whose blast radius fans across the codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Do not force it into a tracer bullet. Sequence it as **expand–contract**:

1. **Expand** — add the new form beside the old one, so nothing breaks. One ticket.
2. **Migrate** — move call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand. The old form still exists, so every batch lands green.
3. **Contract** — delete the old form once no caller remains. One ticket, blocked by every migrate batch.

When even the batches cannot stay green alone, keep the sequence but let them share an integration branch, and add a final integrate-and-verify ticket blocked by all of them — green is promised only there.

## Publishing to a tracker

Offered once, only when `tracker.system` is configured, and only after the user has seen the slice list. On approval, create issues in dependency order (blockers first, so edges can reference real keys), then write each returned key into its local ticket's `Tracker:` line.

The local file remains the source of truth. A project with no tracker loses nothing — that is the supported default, not a degraded mode.
