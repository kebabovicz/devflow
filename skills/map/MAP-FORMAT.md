# The map and its decision tickets

## `map.md`

The whole effort at low resolution, loaded once per session. Open tickets are **not** listed here — they are found by scanning `issues/`, so the map never goes stale about them.

```markdown
# <effort name>

## Destination

<what reaching the end of this map looks like — one or two lines. Every session
orients to it before choosing a ticket; everything past it is out of scope.>

## Notes

<domain, standing preferences for this effort, skills every session should call>

## How it works today

<recon: how the affected area works now, the extension points, the traps.
Written during charting, appended to by any ticket that learns something new.
This is the artifact that stops the next session re-exploring from zero.>

## Decisions

<!-- the index: one line per resolved ticket, enough to judge relevance -->
- [<ticket title>](issues/NN-slug.md) — <one-line gist of the answer>

## Not yet specified

<!-- in-scope fog: the questions you can tell are coming but cannot phrase
     sharply yet. Graduates into tickets as the frontier advances. -->

## Out of scope

<!-- work consciously ruled beyond the destination. Never graduates; returns
     only if the destination is redrawn, and then as a fresh effort. -->
- <gist> — <why it is out> ([closed ticket](issues/NN-slug.md))
```

## `issues/NN-slug.md`

One question per file, numbered from `01` in creation order. Sized to be resolved in one session.

```markdown
# NN — <the question, as a question>

Type: research | grilling
Status: open | claimed | resolved
Blocked by: 03, 05        <!-- or: none -->

## Question

<the decision or investigation this ticket resolves, and why it matters —
what downstream work is waiting on it>

## Answer

<!-- written at resolution: the decision, why it won, what lost and why.
     Assets created while resolving (research digests, prototypes) are
     linked, not pasted. -->
```

**Types.** `research` — a fact from outside the working directory: what a library does, how others solved it, what the API docs say. Resolved by the agent alone, parallelizable, costs the user no attention. `grilling` — the user's own judgment: priorities, trade-offs, how it should feel. Resolved only in live conversation.

**Frontier** — tickets that are open, unblocked (every id in `Blocked by` is resolved), and unclaimed. First by number wins. `Status: claimed` is the claim: set it and save *before* any work, so a parallel session skips the ticket.

**Wiring is a second pass.** Create tickets first, then add `Blocked by` edges — a ticket cannot reference a number that does not exist yet.
