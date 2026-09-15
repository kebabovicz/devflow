# Cutting implementation tickets

The map's last act: turn the spec and the design into work someone can take.

**The engine CLI, written `devflow` below, ships with the plugin as `bin/devflow` in its root — the directory `${CLAUDE_SKILL_DIR}/../..` points at. It is not on PATH; invoke it by that path.**

**`map.md` writes the work branch in backticks** — ``Ветка работы — `feature/ABC-42` ``. The stop gate and the ticket gate both find the effort that belongs to a working tree by reading that name out of the map, and the ticket gate only accepts the backticked form: a bare word in prose is not a branch reference.

## `tickets/NN-slug.md`

Numbered from `01` in dependency order — blockers first.

```markdown
# NN — <ticket title>

Blocked by: 02, 03        <!-- or: none — can start immediately -->
Status: open | in progress | awaiting review | done | blocked
Contract: draft           <!-- approved by a person before work starts -->
Reported: <iso> by <who> commit <sha>   <!-- written by `ticket report` -->
Accepted: <iso> by <who>                <!-- written by `ticket accept` -->
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

## Open questions

<empty in a freshly cut ticket. Filled later, by whoever implements an
EARLIER ticket and finds something that changes this one.

Write entries with `devflow question add <ticket> --text -` rather than by
hand: it blocks the ticket, records the status to restore, and numbers the
entry. One block per question, its state on the heading:

### Q1 · open · asked 2026-09-14T17:00:00Z · was: open

**One bold sentence saying what is needed.** Then the options, numbered, each
with what it costs. Then the proposal.

### Q2 · answered 2026-09-14T18:10:00Z · asked 2026-09-14T17:30:00Z

the question, as it was asked

**Answer:**

what was decided

Settled entries stay — the trail of what was decided is why they are kept —
and stop blocking the ticket. The older one-line form still reads as an open
question, so tickets cut before this existed keep working:

- from 02, while implementing: the session token is issued per device, so
  the user endpoints may need a device id in the path — decide before this
  ticket starts.

A ticket with an unanswered question here is not ready to take.>
```

## A decision from one ticket does not rewrite the next one

Implementing a slice regularly turns up something that changes a later slice — and that later slice usually has slices of its own depending on it. Rewriting the chain from inside the current ticket plans it without what the later ticket will know when it starts, and the further down the chain, the more speculative the rewrite gets.

So: say it out loud, write it into the ticket it concerns under *Open questions*, and leave it to be settled there.

**Finding the tickets it concerns is a graph walk, not a guess.** Take the current ticket's number, collect every ticket whose `Blocked by` names it, then every ticket whose `Blocked by` names one of those, and so on to the end of the chain. Those are the tickets downstream of this decision — the ones whose ground just moved. Matching by title or by topic misses exactly the case that matters, where the affected ticket is two steps away and named after something else.

**An unanswered question makes the ticket un-takeable**: filing one blocks the ticket, so `/devflow:build` skips it and moves on rather than guessing, `/devflow:task` puts the question to the user before starting. Answering one is a design decision — it belongs to `/devflow:map`, and if the answer changes the design, `design.md` changes with it.

## The contract

*What it delivers* and *Acceptance* together are the ticket's contract: what will be true when this is finished, and how anyone tells. They are not a separate document — the ticket already carries both. The `Contract:` header says only whether a person has agreed to what they say.

`draft` — written, waiting on the user. `approved <iso> by <who>` — agreed, and the ticket can be taken. A ticket that fills neither section has no contract at all, and `devflow ticket take` refuses it: nobody could say when it was done.

**Approving is the user's act.** A session drafts and proposes — `devflow contract draft <ticket> --delivers - --acceptance -` — then stops. It never runs `devflow contract approve` for itself. Editing an approved contract returns it to `draft`, because what was agreed is no longer what the ticket says.

Tickets cut before this header existed carry no `Contract:` line. Both their sections are filled and the slicing they came from was reviewed, so they stay takeable; anything reading them sees the state `legacy`, which is the truth — reviewed once, but not by this gate.

## Finishing is two acts

An executor reporting its own work finished has checked nothing — it is the same party on both sides. So finishing is split, and the two halves are different commands run by different people.

`devflow ticket report <ticket> --commit <sha>` is the executor's. It says the code is written, the acceptance boxes are ticked, and this commit carries it; it refuses on an unticked box or a commit the repository does not have. It moves the ticket to `awaiting review` and drops the claim. It never writes `done`.

`devflow ticket accept <ticket>` is the user's answer. It writes `done` and records who accepted and when. A session does not run it — `guard.sh` refuses, and the `DEVFLOW_ALLOW=1` prefix is what the user's explicit yes looks like.

**The unattended loop reports; it does not accept.** A run of ten tickets ends with ten waiting to be accepted, not ten done. That is the point: the loop checked its own work and nothing else has.

A ticket closed before these headers existed carries neither, and reads `legacy` — closed by whatever the rule was then, not by this one. Nothing rewrites it.

## Statuses

`open` — ready to take once its blockers are done. `in progress` — a session is implementing it; the stop gate reads this as "an iteration is in flight". `awaiting review` — **reported and waiting to be accepted**: `devflow ticket report` sets it, records who reported it against which commit, and drops the claim. A session stopping in that state is handing over, not dying. The stop gate lets it pass; `/devflow:build` never takes it — a ticket waiting on a human does not belong to an unattended loop. `done` — **accepted**: a person looked at the reported work and said so, and `devflow ticket accept` wrote the `Accepted:` line. A session never writes this status. `blocked` — an unanswered question or a gap in the design stopped it; the loop set this and moved on.

**Write the canonical value, accept its synonyms when reading.** Tickets in the wild carry `todo` for `open` and `awaiting` for `awaiting review` — a ticket written before this list settled, or by hand. Anything reading a ticket treats those as the same state; anything writing one writes the canonical word above. A status outside this list is shown as-is and never silently reinterpreted: an unknown word is a ticket to look at, not a ticket to skip.

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
