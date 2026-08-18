---
description: Pre-implementation interview — pull the full picture out of the user's head before any code is written. Works for a feature in an existing project AND for a brand-new project that is still just an idea ("I want a fitness app"). Called standalone it produces an approved spec; called from /devflow:map it resolves one decision ticket. Use when the user wants to shape or discuss something before building it.
---

# Discuss: $ARGUMENTS

The user has a picture in their head; you cannot read minds. Every decision you would silently make on your own is a question you owe them — asked now, while it costs one sentence, not after implementation, when it costs a rewrite. This skill is interrogation and negotiation. **No implementation happens here.**

## Two callers

- **From `/devflow:map`**, resolving a `grilling` decision ticket. The scope is that ticket's question, the map's *How it works today* section is your homework already done, and *Decisions* holds what earlier tickets settled — read them before asking, never re-litigate a resolved decision. The output is the decision plus its rationale and rejected alternatives, returned to the map; **the map writes the spec, not you**.
- **Standalone**, on a whole idea. You own the full protocol below end to end, including writing the spec file.

Everything between the two is identical: the same rounds, the same questions, the same refusal to decide silently.

## Two grounds

- **Feature in an existing project** — the ground is the code. Homework before the first question: explore the affected flows, the manifest (`.devflow/project.yml`), the tracker issue. **Never ask what the repo already answers** — questions built on ignorance burn the user's patience and their trust in the questions that matter.
- **Greenfield** — "$ARGUMENTS" is an idea with no repo behind it. There is no code to ground in; the ground is the problem: who it's for, what pain it removes, what the one core scenario is. Start wider than features — a feature list without an audience and a core loop is a wish, not a plan.

The protocol below is the same for both; only the interview axes differ.

## Protocol

### 1. Restate

Present back what you understood: for a feature — current behavior (as found in the code) → what the user seems to want → the deltas; for greenfield — the idea as heard → the biggest unknowns. If "$ARGUMENTS" contradicts the code or contains an internal contradiction, surface it now.

### 2. Interview in rounds — prose by default

**Prose is the instrument.** Ask in plain text, numbered, each question carrying your recommended answer so the user can settle a round in a few words:

```
❓ Q1 — <question title>: <the question, with as much context as it needs>
➡️ <your recommended answer, and why>
```

Text holds nuance that a menu cannot: the user can accept half an option, name a condition, redraw the fork, or answer something you did not think to ask. That extra half-sentence is usually the load-bearing part of the answer — a picked label discards it silently.

**AskUserQuestion is the exception**, for a fork that is genuinely enumerable AND whose options are genuinely exclusive — a small closed set where the whole answer fits in a short label and no qualification is expected (a base branch, push or keep local, which of three existing libraries). The tell that a menu is wrong: you find yourself writing an option description that carries the real content, or you would not be surprised by an answer outside the list. **A menu that flattens the answer costs more than the seconds it saves** — the user picks the nearest label, you record it as a decision, and the difference between "nearest" and "right" surfaces after implementation.

Never offer a menu for the user's vision of how something should work and feel, for motivations and priorities, for "walk me through the scenario", or for anything where you cannot honestly enumerate the answers.

**Follow up on every answer** — if it opens new ground, contradicts an earlier answer, or hides an ambiguity, chase that in the next round instead of marching down a checklist. Keep looping as long as rounds produce decisions — a real interview is rarely one round.

**Rounds follow the decision tree, not a checklist.** Decisions branch: the answer to one opens the questions that hang off it. The **frontier** is every decision whose prerequisites are already settled — exactly the questions you can ask now without guessing at answers you have not heard. Ask the whole frontier in one round, then recompute it from what came back: settled decisions push the frontier outward, and a question whose answer depends on another question still open belongs to a *later* round. The session converges when the frontier is empty.

**Facts are your job; decisions are the user's.** When a frontier question needs a fact from the environment — what the code does, what a library supports, what the manifest says — dispatch a subagent to find it instead of asking. Do not block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier now.

A question earns its slot only when all three hold:

- different answers produce different plans (a real fork);
- nothing already answers it (the code, the manifest, an earlier answer);
- you would otherwise pick silently.

**Feature axes** (skip any the repo answers): scope and non-goals • behavior at the edges (empty states, failures, concurrency, permissions) • data and contracts (shapes, persistence, migration, API compatibility) • integration points • quality bar (verification, performance, what "done" means).

**Greenfield axes**: audience and the pain being removed • the core loop — the one scenario the product exists for • MVP cut: what's in v1, what's explicitly LATER • platform and stack • data: accounts, sync, offline, privacy • distribution and monetization, when relevant • done-criteria for v1.

### 3. "I don't know" is a legitimate answer

Never let it resolve silently. The ladder:

1. propose fitting options yourself, with trade-offs and a recommendation — this is the skill's main job when the user's picture has a hole;
2. no credible options come to mind → don't invent plausible-sounding ones: ask narrowing follow-up questions until options emerge;
3. still open, or the answer needs real evidence (market, competitors, a technology choice) → record it as an open question and offer `/devflow:research <question>` — never fake research inline.

### 4. Contentious calls

Where you disagree with the user's stated direction, spot an inconsistency between their answers, or see a stronger alternative — say so, once, with trade-offs and a recommendation. You are a participant in the design discussion, not a stenographer. The user's decision after hearing the argument is final; record the losing option and why it lost.

### 5. Assumption ledger

Everything you would still decide silently after the interview goes into an explicit list: "unless you say otherwise, I will: X, Y, Z". The user confirms or edits it. An assumption the user never saw is a future bug report.

### 6. Converge and write

When a round produces no new decisions — stop asking; interrogation past that point is theater.

**Called from the map**: write the decision, its rationale, and the alternatives that lost into the ticket's `## Answer`, and hand the gist back — the map records it and clears the fog the answer lifted. Stop there; the spec is the map's job, and a second author guarantees two versions that drift.

**Standalone**: write the file.

- **location**: manifest present → `<maps.specs_dir>/<kebab-case-goal>.md` (a standalone spec; a map keeps its own inside `<maps.dir>/<effort>/`); greenfield / no repo → propose a path (the future project's docs folder, or wherever the user keeps notes) and let the user pick;
- **contents**: goal and done-criteria • decisions log (question → decision → why, rejected alternatives included) • confirmed assumptions • non-goals / explicit LATER list • open questions (anything deferred — flagged, never silently resolved) • verification strategy. Greenfield adds: audience and problem, the core loop, MVP scope.

The file is the artifact — the chat is not. The session dies, the spec survives.

## Hand-off

Called from the map, hand back to it — it picks the next ticket. Standalone, present a short summary, then hand over:

- anything past a one-commit blast radius → `/devflow:map <goal>`, which carries the idea through detailed design and slicing and consumes what this interview settled;
- a single-commit change with the picture already complete → `/devflow:task <spec path>`;
- greenfield → open questions first via `/devflow:research`, then scaffold the repo, `/devflow:init`, and `/devflow:map` pointed at the concept file.

## Rules

- **No implementation, no file edits beyond the spec file.** The strongest temptation is "it's clear enough, let me just build it" — that instinct is the exact failure this skill exists to stop.
- Silence is not consent: an unanswered question goes to "open questions"; it never gets a silently-picked answer.
- At most 3–4 questions per round — never a wall of ten. A frontier wider than that is split across rounds, the questions that constrain the most going first.
- Re-running on an existing spec is an update conversation: diff new decisions against the file, don't start over.
