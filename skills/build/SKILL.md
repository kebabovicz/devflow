---
description: Autonomous build mode — take the next ready implementation ticket from a decision map, implement it in a fresh context, verify, commit, mark it done. One ticket per invocation; designed to be driven by /loop. Use when grinding through a map's tickets without supervision.
disable-model-invocation: true
---

# Build

**Read `${CLAUDE_SKILL_DIR}/../OUTPUT-STYLE.md` before your first message and follow it** — it binds every message this skill prints and every file it writes for a person to read.

Read `.devflow/project.yml` → `maps.dir` (default `.devflow/maps`). Tickets live at `<maps.dir>/<effort>/tickets/`, their design at `<maps.dir>/<effort>/design.md`. No tickets anywhere → stop and say `/devflow:map` has to close an effort into tickets first.

This is the **autonomous** counterpart of `/devflow:task`: same cycle, no approval gates, one ticket per invocation. Everything it needs was decided in the map — that is what makes running it unattended defensible.

**Branch check first**: you must be on a task branch, never `git.base_branch` (the guard blocks commits there anyway). If the effort's tickets name a branch, switch to it; on the base branch, create one per `git.branch_pattern` and record it at the top of the effort's `map.md`.

**Clean-tree invariant**: `git status` must be clean before you pick a ticket. Dirty means a previous iteration died between work and commit — do NOT start new work. Match the leftover changes to their ticket (its `Status: in progress` says which), finish THAT commit first, then proceed.

## One iteration = one ticket

1. **Pick** the first ticket on the frontier: `Status: open` and every id in its `Blocked by` already `done`. Set `Status: in progress` before any work — the marker is what the stop gate reads, and what tells the next session where a dead iteration stopped. Several efforts open → take the one the user named, or the only one with a ready ticket; ambiguity is a reason to ask, not to guess.
2. **Read what was decided**: the ticket, plus the `design.md` sections it names and the map's *How it works today*. **A gap in the design is a blocker, not an invitation** — if the ticket needs a decision nobody made, set `Status: blocked` with the question written into the ticket and move to the next one. Guessing here re-creates the exact failure the map exists to prevent.
3. **Implement in a fresh context**: delegate implementation + verification to a subagent (Task tool, general-purpose) — give it the ticket text, the design sections, the manifest's `test` section, and the project conventions pointer (CLAUDE.md). It implements following existing patterns (read sibling files first), runs the ticket's acceptance checks, and reports: files changed, verification output, anything learned. You stay the orchestrator — your context holds the loop's state, not the implementation noise; that is what keeps quality flat across a long run. The subagent inherits the session model deliberately (it writes production code — never downgrade it). Exception: a trivial ticket (single small file, no test changes) may be done inline.
   - **Red/green when tests are the acceptance**: the failing test is written and seen red first, then implemented until green — a test that has never failed proves nothing.
4. **Verify the claim yourself**: read the diff (`git diff`), check it against the ticket's acceptance checklist and the design, re-run the checks / `test.run`. The subagent's report is a claim, not a verification. Checking it against the design means three specific things, not a general look: something the ticket required that is missing or half-done, behavior in the diff that nothing asked for, and a requirement that looks implemented but does not do what the design decided. **A change that reaches into a later ticket is not fixed here** — write the question into that ticket and carry on; re-planning the chain unattended is exactly what the map exists to prevent. Not green → fix (or send back) until green, or set `Status: blocked` with what you learned.
5. **Mark it done**: tick the acceptance checklist and set `Status: done` in the ticket file. If the iteration involved a judgment call — a defensible alternative existed (locking strategy, API shape, error semantics, library choice) — the ticket MUST carry it: `⚠ judgment call: chose X over Y`. After a run the user greps the effort for `⚠` to find every fork the loop took; an unrecorded fork is invisible forever.
6. **Commit the code**: the files this ticket touched, in one commit, message referencing the ticket. Tickets themselves are never committed — the map lives outside git by design. Never commit unrelated drive-by changes; a pre-existing bug fixed en route is a separate commit before this one. The iteration is NOT done until this commit exists — a green test with a dirty tree is a failed iteration, and the stop gate enforces it.
7. **Knowledge sync**: update docs mapped in `docs.map` if the ticket changed a documented flow (definition-of-done); same for `.devflow/project.yml` if it changed ports, services, env, auth, or health behavior.

## Loop discipline

- ONE ticket per invocation. Finishing early is success, not an invitation to start the next one — the loop will call you again.
- **An iteration that cannot finish its ticket writes a work handoff into it** (per `${CLAUDE_SKILL_DIR}/../handoff/SKILL.md`) before stopping: where it got to, what did not work, what it would do next. The next iteration starts from that instead of from the ticket text alone.
- Everything blocked and nothing buildable → report the blockers and stop the loop instead of churning. **Blocked tickets must not rot**: a blocker that is a missing decision goes back to `/devflow:map` as a new decision ticket; a blocker that is a real defect gets offered as `/devflow:issue`. Note the outcome next to the ticket either way.
- **Loop end = handoff**: when the run finishes — every ticket done, or stopped on blockers — offer a review handoff for the whole branch (format per `${CLAUDE_SKILL_DIR}/../handoff/SKILL.md`, scope: branch vs `git.base_branch`). An autonomous run is exactly the "work done while the user wasn't watching" case the handoff exists for; the tickets' `⚠ judgment call` notes feed its 🔴 section verbatim.
- **All tickets done → the effort is finished**: hand back to `/devflow:map`, which closes the effort — carrying out whatever outlives it and archiving the rest.
