---
description: Assemble a review handoff for completed work — a risk-ranked attention map (judgment calls first), verified-vs-derived split, and two-minute re-checks with real outputs. Use when asked to prepare work for review, to summarize what needs human eyes ("подготовь к ревью", "что мне проверить"), or after work done without devflow skills. Also the format authority other devflow skills render their close-the-loop reports with.
---

# Review handoff: $ARGUMENTS

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
- **🔴 judgment calls**: anywhere a defensible alternative existed (locking strategy, API shape, error semantics, library choice) — state the alternative and why you chose against it. This is what the human ratifies; everything else a machine can check.
- **🟡**: claims taken from reading code/schemas/docs but never executed this session. An assumption that needs the user's confirmation is 🔴, not 🟡.
- **🟢 is a closed list**: renames/moves, codegen output, import/using adjustments, formatting, comment typo fixes, boilerplate replicated from an existing pattern in the same repo. Not on the list → not green.

## Rules

- **"Verify in 2 minutes" is the only falsifiable section** — the rest is self-assessment by the same model that did the work, a floor for attention, not proof. Commands there must have actually been executed this session, with the real observed output quoted — never aspirational ("this should return..."), never commands you didn't run.
- Never include secrets in commands or outputs (token values, passwords, connection strings) — same discipline as everywhere in devflow.
- Don't pad: an empty pass on a section is success. Inventing risks to fill 🔴 trains the reader to skim — the failure mode this format exists to prevent.
