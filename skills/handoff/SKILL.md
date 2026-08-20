---
description: Hand work off in both directions — write a handoff, or pick one up. Writing: a risk-ranked review handoff for the human checking finished work, or a work handoff for the next session picking up work you are stopping mid-way. Reading: called in a fresh session it finds the last handoff, checks it against the repository, and shows where it would continue. Use when asked to prepare work for review, to summarize what needs human eyes, to pass an unfinished ticket or effort on, or to resume one. Also the format authority other devflow skills render their close-the-loop reports with.
---

# Handoff: $ARGUMENTS

**Read `${CLAUDE_SKILL_DIR}/../OUTPUT-STYLE.md` before your first message and follow it** — it binds every message this skill prints and every file it writes for a person to read.

The baton has two ends: writing one and picking one up. **Three modes, and the first line of your answer says which one you took** — so a wrong guess costs one word to correct, not a lost handoff.

- **Write a review handoff** — the work is finished. The reader is the human whose bottleneck is verifying agent work; spend their attention where the risk is.
- **Write a work handoff** — the work is unfinished and you are stopping. The reader is the next session, which knows nothing except what you write down.
- **Resume** — read the last handoff, check it against the repository, and show where you would continue. This is what a fresh session calls.

**How to pick.** The words after the skill name decide it, in whatever language they come in: anything meaning *save, record, write it down, hand this over* → write; anything meaning *continue, pick up, resume, where were we* → resume. Judge the intent, not a keyword list.

With no such word, read the state: this session has edits, a ticket marked `Status: in progress`, or a dirty tree → write (finished work → review handoff, stopped work → work handoff). This session has done nothing and a handoff exists on disk → resume. Nothing done and nothing on disk → say so plainly instead of guessing.

**A work handoff is narrower than it looks, and writing one that nobody needed is not free** — it costs the session's remaining attention and produces a file the next reader has to reconcile with reality. It earns its place when the work is *travelling*: another harness, another directory or repository, a colleague, a side task parked mid-phase. Otherwise the right move at that boundary is usually continuing, clearing, a subagent, or compacting. `${CLAUDE_SKILL_DIR}/PHASE-BOUNDARIES.md` holds that decision in order, along with the three cases where devflow mandates a handoff whatever the tree says.

---

# Review handoff — for the human

The human's bottleneck is verifying agent work, not producing it. A handoff exists to spend their attention where the risk is: judgment calls and irreversible changes get eyes, mechanical changes get a count, and every key claim comes with a re-runnable check. Plausible-looking output reduces critical engagement — so the handoff must point at risk explicitly, not read smoothly.

**Scope** from "$ARGUMENTS": a branch (diff vs `git.base_branch` from `.devflow/project.yml`), or — default — uncommitted changes plus the current branch's commits over base. Works without a manifest (detect the base branch or ask). When the work was done by another session or agent and you only have the diff, say so: the judgment-call section is then reconstructed from the diff and weaker — flag forks you can *see*, don't invent rationales you don't know.

## The format

```
## Review handoff

🔴 Needs your eyes (N)
  - <file:line> — chose X over Y because Z          ← judgment calls, verbatim rationale
  - <file:line> — migration renames a column         ← auto-red, why it's red

🟡 Derived, not executed (N)
  - <claim> — source: <read the code / swagger / docs>, never ran it

🟢 Mechanical (N files)
  - <count + one-line nature>: "14 files — rename + usings"

Verify in 2 minutes — commands I already ran (my output shown; re-run them yourself):
  $ <command>            → <actual result observed>
  $ <command>            → <actual result observed>
```

All four sections are always present — a missing section must read as an anomaly, not a style choice. Empty is one honest line: `🔴 none — change is mechanical (rename across 14 files)`. Content scales with risk; a three-line fix gets a three-line handoff.

## Classification rules — not self-assessment

- **Auto-🔴, no judgment allowed**: DB migrations / schema changes; auth, authz, crypto, secrets handling; deletion or mutation of existing data; public contract changes (routes, DTOs, response shapes, events, published interfaces); concurrency and transactions (locks, async coordination, isolation); error paths that swallow, retry, or transform failures.
- **🔴 judgment calls**: anywhere a defensible alternative existed (locking strategy, API shape, error semantics, library choice) — state the alternative and why you chose against it. This is what the human ratifies; everything else a machine can check. A **deliberate divergence from a pattern used elsewhere in the codebase** is always one of these.
- **🟡**: claims taken from reading code/schemas/docs but never executed this session. An assumption that needs the user's confirmation is 🔴, not 🟡.
- **🟢 is a closed list**: renames/moves, codegen output, import/using adjustments, formatting, comment typo fixes, boilerplate replicated from an existing pattern in the same repo. Not on the list → not green.

## Rules

- **"Verify in 2 minutes" is the only falsifiable section** — the rest is self-assessment by the same model that did the work, a floor for attention, not proof. Commands there must have actually been executed this session, with the real observed output quoted — never aspirational ("this should return..."), never commands you didn't run.
- Never include secrets in commands or outputs (token values, passwords, connection strings) — same discipline as everywhere in devflow.
- Don't pad: an empty pass on a section is success. Inventing risks to fill 🔴 trains the reader to skim — the failure mode this format exists to prevent.

---

# Work handoff — for the next session

You are stopping mid-work. The next session starts with an empty head: everything you learned that is not written down is lost, and it will rediscover it the expensive way, or worse, decide it differently. **The handoff is the only thing that crosses.**

**Scope** from "$ARGUMENTS": one ticket (the default when a ticket is in progress), or a whole effort up to where it stopped — several tickets done, one half-finished, the rest untouched.

## Where it goes

- **A ticket** → a `## Handoff` section appended to the ticket file itself. State belongs to the ticket: the next session opens it anyway, and one file cannot drift from another. Leave `Status: in progress` — that marker is what says the work is live, and the stop gate reads it.
- **A whole effort** → `<maps.dir>/<effort>/HANDOFF.md`, overwritten each time. One current picture, not an archive of stopping points.
- **No map** (work started without one) → propose a path and let the user pick; a file the next session will not find is not a handoff.

## What it says

Written for someone competent who was not here. Six things, and nothing else:

1. **The goal, in one or two lines** — what this work is for, not a restatement of the ticket title.
2. **Done, and where it lives** — what works now, split by *committed* (name the commits) versus *sitting in the working tree*. This distinction is the one that ruins a handoff when it is missing.
3. **Where exactly you stopped** — not "in progress": the file, the function, the step, and what your next action would have been. A precise stopping point is worth more than a long summary.
4. **What did not work** — dead ends, approaches tried and abandoned, and *why*. Without this, the next session spends its first hour re-walking them. This section is usually the most valuable one and the easiest to skip.
5. **Decisions you made along the way** that are not in the design or the ticket — and they must not stay here alone: a decision that outlives this handoff belongs in `design.md`, so move it there and reference it. The handoff is a relay baton, not a filing cabinet.
6. **What is left** — the remaining steps as you understand them now, plus which devflow skills the next session should call.

Reference, never duplicate: the ticket, `design.md`, the spec, commit hashes, the diff. Anything already recorded gets a pointer — a copy is a second version waiting to drift.

**Redact secrets.** Same discipline as everywhere: no token values, passwords, or connection strings, not even partial.

## Uncommitted work must be addressed, not mentioned

Unfinished work usually means a dirty tree, and a dirty tree does not travel. Before handing off, settle it explicitly:

- **Next session on this machine** → leaving it in the working tree is fine; say so, and name the files.
- **Anywhere else** (another machine, a colleague, a cloud session) → uncommitted work simply will not arrive. Offer a WIP commit on the task branch, marked as such in the message, and say plainly that it is a checkpoint rather than a finished change.

Never hand off silently over a dirty tree — the next session will read the handoff, find files it cannot explain, and trust nothing else in the document. (The stop gate fires here for the same reason; the handoff is the answer to it, not a way around it.)

## Close by saying how to pick it up

The last line of a work handoff report names the path it was written to and the call that resumes it — `/devflow:handoff продолжи`, in the user's language. A handoff nobody knows how to open is a file, not a handoff.

---

# Resume — picking one up

A fresh session, an empty head, and somewhere on disk the last one wrote down where it stopped. This mode finds that, checks it, and shows what continuing would mean. **It does not start working.**

## 1. Find the candidates

Three places, and nothing clever:

- ticket files carrying a `## Handoff` section — usually with `Status: in progress`;
- `HANDOFF.md` in any open effort under `<maps.dir>` — resolved in the **main working tree** (`git rev-parse --git-common-dir`'s parent), since a worktree does not carry the map;
- a path given in "$ARGUMENTS", which wins over both.

**Several candidates → list them and ask which one**: path, one line of what it is about, and when it was last modified. Guessing here is how a session resumes the wrong work and does not notice for an hour. **One candidate** → take it, and say which. **None** → say plainly that there is nothing to pick up, and stop; do not perform a search across the repository to look thorough.

A handoff written to a path outside the project (the user's own notes directory, for instance) is not discoverable — it has to be named in the argument. Say so rather than reporting that nothing was found.

## 2. Check it against the repository before showing anything

**A handoff is a claim; the repository is the fact.** Between the two sessions the branch may have moved, someone may have committed the working tree, a ticket may have been closed. Check what the document asserts:

- commits it names — are they on this branch (`git log`)?
- work it says is sitting in the working tree — is it (`git status`)?
- the branch it assumes — is that the one checked out?
- the ticket status it assumes — is that what the file says now?

**Discrepancies are reported first, before the summary**, and they are not smoothed over. Continuing on top of a description that has drifted from the repository is worse than starting cold, because the wrong parts are invisible.

## 3. Show where you would continue, then wait

Six lines, not a re-telling of the file: the goal; where the previous session stopped, precisely; what the next action would be; what did not work, so it is not re-walked; what is left; and any discrepancy from the check above.

Then **stop and wait for the user**. They decide whether to continue from that point, take something else first, or throw the plan away — a resumed session that starts implementing on its own has taken a decision that belonged to them.

Once the work continues, the handoff stops being current: the next stop rewrites it, and a finished ticket drops its `## Handoff` section instead of leaving a stale one for the session after that.
