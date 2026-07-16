---
description: Pre-implementation interview — pull the full picture out of the user's head before any code is written. Works for a feature in an existing project AND for a brand-new project that is still just an idea ("I want a fitness app"). Produces an approved spec/concept file that /devflow:task and /devflow:ralph-plan consume. Use when the user wants to shape or discuss something before building it.
---

# Discuss: $ARGUMENTS

The user has a picture in their head; you cannot read minds. Every decision you would silently make on your own is a question you owe them — asked now, while it costs one sentence, not after implementation, when it costs a rewrite. This skill is interrogation and negotiation. **No implementation happens here.**

## Two grounds

- **Feature in an existing project** — the ground is the code. Homework before the first question: explore the affected flows, the manifest (`.devflow/project.yml`), the tracker issue. **Never ask what the repo already answers** — questions built on ignorance burn the user's patience and their trust in the questions that matter.
- **Greenfield** — "$ARGUMENTS" is an idea with no repo behind it. There is no code to ground in; the ground is the problem: who it's for, what pain it removes, what the one core scenario is. Start wider than features — a feature list without an audience and a core loop is a wish, not a plan.

The protocol below is the same for both; only the interview axes differ.

## Protocol

### 1. Restate

Present back what you understood: for a feature — current behavior (as found in the code) → what the user seems to want → the deltas; for greenfield — the idea as heard → the biggest unknowns. If "$ARGUMENTS" contradicts the code or contains an internal contradiction, surface it now.

### 2. Interview in rounds

Use the AskUserQuestion tool — 2–4 questions per round, each with concrete options and your recommended option first. Free-text question walls are forbidden: options force *you* to think through the answer space, and the user picks in seconds instead of writing essays. Order rounds by leverage: answers that constrain everything else (audience, core loop, architecture, data shape) before cosmetics. Keep looping rounds as long as they produce decisions — a real interview is rarely one round.

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

When a round produces no new decisions — stop asking; interrogation past that point is theater. Write the file:

- **location**: manifest present → `<ralph.specs_dir>/<kebab-case-goal>.md`; greenfield / no repo → propose a path (the future project's docs folder, or wherever the user keeps notes) and let the user pick;
- **contents**: goal and done-criteria • decisions log (question → decision → why, rejected alternatives included) • confirmed assumptions • non-goals / explicit LATER list • open questions (anything deferred — flagged, never silently resolved) • verification strategy. Greenfield adds: audience and problem, the core loop, MVP scope.

The file is the artifact — the chat is not. The session dies, the spec survives.

## Hand-off

Present a short summary, then hand over:

- feature, small (one-commit blast radius) → `/devflow:task <spec path>`;
- feature, large (multi-session) → `/devflow:ralph-plan <goal>` — it consumes the same spec file from `specs_dir`;
- greenfield → open questions first via `/devflow:research`, then scaffold the repo, `/devflow:init`, and `/devflow:ralph-plan` pointed at the concept file.

## Rules

- **No implementation, no file edits beyond the spec file.** The strongest temptation is "it's clear enough, let me just build it" — that instinct is the exact failure this skill exists to stop.
- Silence is not consent: an unanswered question goes to "open questions"; it never gets a silently-picked answer.
- At most 4 questions per round. Ten forks to resolve → several rounds, highest-leverage first.
- Re-running on an existing spec is an update conversation: diff new decisions against the file, don't start over.
