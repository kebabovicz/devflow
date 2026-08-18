# The spec and the detailed design

Two documents, deliberately separate. The spec answers **what and why**; the design answers **how exactly**. Merged into one file, the design collapses into a list of bullet points — and that is precisely where the implementing agent starts inventing.

Both are written from the map's resolved tickets. A statement neither the tickets nor the recon support does not belong in either document.

## `spec.md`

```markdown
# <effort name>

## Problem

<the problem from the user's perspective — what hurts today>

## Solution

<the solution from the user's perspective — what changes for them>

## Scenarios

<a numbered list of user scenarios, extensive: every path the feature must
support, written as "as an <actor> I want <capability> so that <benefit>">

## Done-criteria

<what makes this effort finished — each one mechanically checkable:
a test that passes, a command with expected output, an observable behavior.
"Looks right" is not a criterion.>

## Out of scope

<what this effort explicitly does not cover, lifted from the map>
```

No file paths, no code snippets — they go stale fastest. Exception: a snippet that encodes a decision more precisely than prose can (a state machine, a schema, a type shape) belongs in the **design**, not here.

## `design.md`

Four sections, all mandatory. An empty one is an honest line saying why it is empty, never a silent omission — a missing section reads as "nobody thought about it", which is exactly the state this document exists to end.

```markdown
# <effort name> — detailed design

## Interfaces and seams

<which modules are touched; what each exposes to callers; through which seam
the behavior will be tested. A seam is where behavior can be observed without
reaching inside. Naming the seam here is what lets tests be written against a
chosen boundary rather than an accidental one.>

## Data shapes and contracts

<schemas, fields, migrations, request and response formats, events, versioning
and compatibility. The most expensive things to change after implementation.>

## Behavior at the edges

<empty states, failures and their handling, retries, timeouts, concurrency,
permissions. The most common place an agent invents behavior on the user's
behalf — every edge left unstated here gets decided silently.>

## Rejected alternatives

<what else was considered and why it lost. Without this the next session
re-invents the rejected option. This section is also the raw material for
an ADR when a decision turns out hard to reverse.>
```

**Interfaces and seams is the handoff to testing.** Whatever seam is named here is the boundary implementation tests target — chosen once, deliberately, instead of settled by whoever writes the first test.
