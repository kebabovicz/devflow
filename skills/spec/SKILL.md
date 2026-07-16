---
description: Pre-implementation interview — pull the full picture out of the user's head before any code is written: scope, edge behavior, data contracts, contentious calls. Produces an approved spec file that /devflow:task and /devflow:ralph-plan consume. Use when the user wants to shape or discuss a feature before building it.
---

# Spec: $ARGUMENTS

The user has a picture in their head; you cannot read minds. Every decision you would silently make on your own is a question you owe them — asked now, while it costs one sentence, not after implementation, when it costs a rewrite. This skill is interrogation and negotiation. **No implementation happens here.**

Works with or without a devflow manifest (`.devflow/project.yml`) — without one, the spec lands wherever the user says.

## Protocol

### 0. Homework before the first question

Explore the affected code; read the manifest and the tracker issue if present. **Never ask what the repo already answers** — questions built on ignorance burn the user's patience and their trust in the questions that matter.

### 1. Restate

Present back: current behavior (as found in the code) → what the user seems to want → the deltas and unknowns you see. If "$ARGUMENTS" contradicts the code, surface it now.

### 2. Interview in rounds

Use the AskUserQuestion tool — 2–4 questions per round, each with concrete options and your recommended option first. Free-text question walls are forbidden: options force *you* to think through the answer space, and the user picks in seconds instead of writing essays. Order rounds by leverage: answers that constrain everything else (architecture, data shape) before cosmetics.

A question earns its slot only when all three hold:

- different answers produce different implementations (a real fork);
- the code / manifest / issue does not already decide it;
- you would otherwise pick silently.

Sweep these axes, skipping any the repo already answers:

- **Scope and non-goals** — what is explicitly OUT. The cheapest question and the most often skipped;
- **Behavior at the edges** — empty states, failures, concurrency, permissions, "what does the user see when it breaks";
- **Data and contracts** — shapes, persistence, migration of existing records, API compatibility;
- **Integration points** — which existing flows this touches, who else consumes them;
- **Quality bar** — how it is verified, performance expectations, what "done" means.

### 3. Contentious calls

Where you disagree with the user's stated direction or see a stronger alternative — say so, once, with trade-offs and a recommendation. You are a participant in the design discussion, not a stenographer. The user's decision after hearing the argument is final; record the losing option and why it lost.

### 4. Assumption ledger

Everything you would still decide silently after the interview goes into an explicit list: "unless you say otherwise, I will: X, Y, Z". The user confirms or edits it. An assumption the user never saw is a future bug report.

### 5. Converge and write

When a round produces no new decisions — stop asking; interrogation past that point is theater. Write the spec file:

- **location**: manifest present → `<ralph.specs_dir>/<kebab-case-goal>.md`; no manifest → propose a path and let the user pick;
- **contents**: goal and done-criteria • decisions log (question → decision → why, rejected alternatives included) • confirmed assumptions • non-goals • open questions (anything the user deferred — flagged, never silently resolved) • verification strategy.

The file is the artifact — the chat is not. The session dies, the spec survives.

## Hand-off

Present a short summary of the spec, then hand over:

- small (one-commit blast radius) → `/devflow:task <spec path>`;
- large (multi-session) → `/devflow:ralph-plan <goal>` — it consumes the same spec file from `specs_dir` and skips re-eliciting what the spec already fixes.

## Rules

- **No implementation, no file edits beyond the spec file.** The strongest temptation is "it's clear enough, let me just build it" — that instinct is the exact failure this skill exists to stop.
- Silence is not consent: an unanswered question goes to "open questions"; it never gets a silently-picked answer.
- At most 4 questions per round. Ten forks to resolve → several rounds, highest-leverage first.
- Re-running on an existing spec is an update conversation: diff new decisions against the file, don't start over.
