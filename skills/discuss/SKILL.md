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

## The code is context, not authority

Two rules that look opposed and are not.

**Ground every question in the project.** Ask in its own terms, naming what is already there: not "which auth do you want" but "services A and B already verify a Keycloak JWT — same path here, or does this surface have different requirements?". A grounded question proves the homework is done and narrows the answer to the real fork; a generic one burns the user's patience and their trust in the questions that matter.

**Existing code answers *what is*, never *what should be*.** A pattern is not a norm because it is present — it may be a good decision, an outdated one, or a mistake nobody had time to undo. Treating the codebase as the standard makes every future change inherit its worst parts, and an agent that only ever validates the status quo is worth less than one that argues with it.

### When the better answer does not fit the current code

Say so — never resolve it silently in either direction. Silently following a bad pattern and silently "improving" one are the same failure: a decision the user never made, in code they maintain.

Name three things: how the project does it today, what you would do instead and why, and **the cost of divergence** — because that, not "better", is the axis the user decides on. Two ways of doing one thing in a codebase is a real tax, paid by whoever reads it next.

Then put the three options to them:

- **follow the existing pattern** — consistency wins, the flaw is recorded as known and left alone;
- **new way here, and migrate the rest** — you also scope that migration, so its price is visible before the choice, not after;
- **new way here only** — the codebase now has two answers, deliberately; this is debt, and it gets written down as debt rather than discovered later as an inconsistency.

Push for the break when the decision is hard to reverse, when the existing pattern is a live source of bugs, or when the new code will outlive the old. Leave it alone when the pattern merely offends taste — that is the case where consistency is worth more than your preference.

Whatever they pick, **a deliberate divergence must be recorded** — in the design's rejected alternatives, and in the ticket that implements it. An unexplained departure from the surrounding style reads as a mistake to the next reviewer, and gets "fixed" back.

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

### 3. Dig for the intent, not just the answers

A request names a want; it rarely names the intent behind it. "Authentication that suits this project" carries its whole meaning in *suits* — a word that means nothing until this particular user fills it in, and that you will otherwise fill in with your own default. **Every vague qualifier is a question**: suitable, simple, proper, standard, normal, like everyone does it.

Three moves turn an answer into an understanding. Reach for whichever fits; a real exchange uses all of them.

- **Ask why, then distrust the first why.** "Because it's simpler" is a proxy, not a reason — simpler than what, and simple along which axis? Behind it sits a deadline, an unfamiliarity, a burned hand from a previous project, or a requirement nobody wrote down. The reason is what a future decision gets checked against; the proxy is worthless six months from now.
- **Offer concrete options to map the space, not to make the user shop.** Two or three real alternatives with their trade-offs — how the user *reacts* to them tells you more than a direct question does, because rejecting something specific is easier than describing something absent. Their objection to option B usually names the constraint they never mentioned.
- **Test the answer with a scenario that would break it.** Not speculation ("what if someday…") — a concrete, checkable near future: a second consumer, a second auth provider, ten times the data, a teammate joining, this thing failing at 3am. If it is planned, the decision changes now; if it is not, that is a **non-goal**, recorded as one. Either way an unexamined assumption stops being invisible.

Chase the answer, not the checklist: an answer that opens new ground, contradicts an earlier one, or hides an ambiguity is worth more than the next question on your list.

### 4. Interview mechanics

**Follow up on every answer** — if it opens new ground, contradicts an earlier answer, or hides an ambiguity, chase that in the next round instead of marching down a checklist. Keep looping as long as rounds produce decisions — a real interview is rarely one round.

**Rounds follow the decision tree, not a checklist.** Decisions branch: the answer to one opens the questions that hang off it. The **frontier** is every decision whose prerequisites are already settled — exactly the questions you can ask now without guessing at answers you have not heard. Ask the whole frontier in one round, then recompute it from what came back: settled decisions push the frontier outward, and a question whose answer depends on another question still open belongs to a *later* round. The session converges when the frontier is empty.

**Facts are your job; decisions are the user's.** When a frontier question needs a fact from the environment — what the code does, what a library supports, what the manifest says — dispatch a subagent to find it instead of asking. Do not block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier now.

A question earns its slot only when all three hold:

- different answers produce different plans (a real fork);
- nothing already answers it (the code, the manifest, an earlier answer);
- you would otherwise pick silently.

**Feature axes** (skip any the repo answers): scope and non-goals • behavior at the edges (empty states, failures, concurrency, permissions) • data and contracts (shapes, persistence, migration, API compatibility) • integration points • quality bar (verification, performance, what "done" means).

**Greenfield axes**: audience and the pain being removed • the core loop — the one scenario the product exists for • MVP cut: what's in v1, what's explicitly LATER • platform and stack • data: accounts, sync, offline, privacy • distribution and monetization, when relevant • done-criteria for v1.

### 5. "I don't know" is a legitimate answer

Never let it resolve silently. The ladder:

1. propose fitting options yourself, with trade-offs and a recommendation — this is the skill's main job when the user's picture has a hole;
2. no credible options come to mind → don't invent plausible-sounding ones: ask narrowing follow-up questions until options emerge;
3. still open, or the answer needs real evidence (market, competitors, a technology choice) → record it as an open question and offer `/devflow:research <question>` — never fake research inline.

### 6. Contentious calls

Where you disagree with the user's stated direction, spot an inconsistency between their answers, see a stronger alternative, or find that the project's own way of doing this is the weaker one — say so, once, with trade-offs and a recommendation. You are a participant in the design discussion, not a stenographer. The user's decision after hearing the argument is final; record the losing option and why it lost.

### 7. Assumption ledger

Everything you would still decide silently after the interview goes into an explicit list: "unless you say otherwise, I will: X, Y, Z". The user confirms or edits it. An assumption the user never saw is a future bug report.

### 8. Converge and write

**The bar is shared understanding, not an empty question list.** Before writing anything, restate the intent in your own words — what the user is actually after, why the chosen shape serves it, and what it deliberately does not cover — and get that confirmed. Not a list of decisions read back: the picture they add up to. If you cannot state the *why* behind a decision without hedging, that decision was never understood, and one more question is cheaper now than a rewrite later.

When a round produces no new decisions and the restatement lands — stop asking; interrogation past that point is theater.

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
