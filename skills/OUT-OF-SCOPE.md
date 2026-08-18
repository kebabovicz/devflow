# The record of what this project will not do

A decision to *not* build something is a decision, and it is the one nobody writes down. The issue gets closed, the map gets archived, the reasoning evaporates — and six weeks later the same request arrives in different words and gets argued from scratch. Worse, it sometimes wins the second time, not because anything changed but because whoever pushed back is not in the room.

`.out-of-scope/` at the repository root fixes that. Two jobs: keep the reason a thing was rejected, and recognise the same request when it comes back wearing different words.

## Where it lives, and who sees it

`.out-of-scope/` at the repo root, **excluded from git** — add it to `.git/info/exclude` before writing the first file, never to `.gitignore` (that file is committed, and the line itself would announce the directory). This is the same rule maps follow, for the same reason: it is one person's record until they decide otherwise.

**Publishing it is the user's call, offered rather than assumed.** A project where the whole team keeps hitting the same rejected requests has a good reason to commit this directory; that is a decision to make once, out loud, not a default.

## One file per concept

```
.out-of-scope/
  dark-mode.md
  plugin-system.md
  offline-sync.md
```

Named for the concept in kebab-case, recognisable from the listing without opening the file. **Not one file per request** — three requests for the same thing are three entries inside one file, which is exactly what makes the deduplication work.

Written as a short design document, not a database row: paragraphs, and a code sample where it makes the constraint concrete.

```markdown
# Dark mode

This project does not support theming or a dark palette.

## Why it is out of scope

The rendering path resolves one palette at build time, in `ThemeConfig`.
Supporting a second would need a theme context threaded through the whole
component tree, per-component style resolution, and somewhere to persist the
user's choice — a structural change to a project whose subject is content
authoring. Theming belongs to whoever embeds the output.

## What it would take

<the honest price, so a future decision to reverse this starts from a number
rather than from zero>

## Prior requests

- ABC-42 — "Add dark mode"
- ABC-87 — "Night theme for accessibility"
- discussion, 14 March — asked again during the onboarding redesign
```

**The reason has to be substantive and durable.** Not "we don't want it" but what in the project's shape or purpose makes it wrong: scope and philosophy, a technical constraint, a strategic choice already made. And not a temporary circumstance — "no time this quarter" is a deferral, not a rejection, and recording it here poisons every later check.

## When to check it

Before doing any of these, read what is in `.out-of-scope/`:

- **`/devflow:issue`** — before filing. A request matching a past rejection gets that surfaced instead of a new ticket.
- **`/devflow:discuss`** — before interviewing. Re-opening a closed question is legitimate; doing it without knowing it was ever closed is not.
- **`/devflow:map`, while charting** — that is where the scope of an effort is drawn, and the boundary may already be drawn on disk.

Match **by concept, not by keyword**: "night theme" matches `dark-mode.md`. Surface it as a question, never as a verdict: here is what was decided and why, does that still hold? Three answers are all normal — it still holds (the new request joins *Prior requests*), it does not (the file is deleted or rewritten, and the work proceeds), or the two things are genuinely different (proceed, and say why they differ).

**`/devflow:task` does not check.** A direct instruction to build something is not a request for triage, and answering an instruction with an old rejection is arguing about the wrong thing. Changing one's mind is the user's prerogative.

## When to write into it

Only when something that *could* have been built is deliberately rejected — the user says no, and the no is about the shape of the project rather than about this month's schedule. Concretely: a `wontfix` in the tracker, a scope boundary drawn during an interview, an *Out of scope* line from a map that outlives the effort it came from.

Never write here for something that is **already implemented** and was closed for that reason. It is a built feature, not a rejected one, and recording it would make later checks report false rejections.

## When the answer changes

Delete the file, or rewrite it to say what changed and when. Old issues are not reopened — they are history. What matters is that the next check reads the current answer, and that whoever reverses a rejection sees the reasoning they are overturning rather than discovering it afterwards.
