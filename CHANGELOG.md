# Changelog

## 0.33.0 — 2026-08-18

- **`skills/handoff/PHASE-BOUNDARIES.md` — when a work handoff is the right move, and when it is the expensive one.** 0.27.0 gave devflow the work handoff without ever saying when to reach for it, so the honest default became "write one whenever stopping", which costs the session's last attention and leaves a file the next reader has to reconcile with reality. A handoff earns its place when the work is **travelling** — another harness, another directory or repository, a colleague, a side task parked mid-phase. Portability is the whole thing it buys.
- **Five options, taken in order, first yes wins**: continue (the next phase needs this one verbatim, or there is window left) → `/clear` (everything here is disposable) → work handoff (it travels) → subagent (scoped tightly enough to run unsteered) → `/compact`. Compacting sits at the bottom deliberately: it is the frequent answer but the worst first reach, and starting there produces the familiar fresh session that is confidently wrong about a decision the summary flattened.
- **The decision belongs at the boundary, never mid-phase.** A phase ends when you think "right, that's dealt with"; in the middle of one there is nothing to decide except continue or delegate the remainder. Compacting mid-phase is how the thread gets lost.
- **A map changes the arithmetic of clearing.** Every move except continuing turns a primary source into a secondary one — full and noisy traded for clean and lossy. But decisions that reached `<maps.dir>` are on disk rather than in the window, so with a map open, clearing costs only what was never written down. Work with no map behind it pays full price, which is the concrete argument for having charted one.
- **Where devflow has already decided, the tree does not apply**: a ticket abandoned before done, an iteration that cannot finish, an effort being parked — those mandate a handoff regardless, because someone else will find the work.
- **The window threshold is named and hedged**: roughly the first 150k tokens is where reasoning stays sharp, as an orientation rather than a limit — it moves with the model and with how dense the context is. The behavioral test is more honest anyway: an agent re-reading files it already read, or restating decisions already made, passed the boundary a while ago.

## 0.32.0 — 2026-08-18

- **`skills/DESIGN-VOCAB.md` — one vocabulary for designing modules.** `DESIGN-FORMAT.md` had been using *seam* since the design layer landed without ever defining it, and 0.30.0 parked working definitions of *depth* and *locality* inside `DESIGN-IT-TWICE.md` because there was nowhere else to put them. Both now point at one file. Eight words defined and defended: **module** (anything with an interface and an implementation — deliberately scale-free), **interface** (everything a caller must know: invariants, call ordering, error modes, required configuration — not just the signature), **implementation**, **depth** (behavior reachable per unit of interface learned), **seam** (Feathers: a place where behavior can be changed without editing in that place), **adapter**, **leverage** for callers, **locality** for maintainers.
- **Substitutions are named and refused.** Not *component* or *service* for module — each drags in a size the word deliberately refuses to fix. Not *API* or *signature* for interface — they cover only the part already visible. Not *boundary* for seam — it belongs to DDD's bounded context, and the two are different decisions. Agreeing in words while disagreeing in fact is exactly what an unshared vocabulary buys.
- **Four principles carried with the words**: depth is a property of the interface, not the implementation (a deep module may be built from small swappable parts that callers never see); the **deletion test** — delete the module in your head, and if the same complexity reappears in every caller it was earning its place; **the interface is the test surface**, so wanting to test *past* it means the module has the wrong shape rather than that the test should reach around; and **one adapter is a hypothetical seam, two make it real** — a seam with one thing behind it is an abstraction waiting for a second consumer that may never arrive.
- **Three framings rejected on the record**: depth as a ratio of implementation lines to interface lines (it rewards padding), interface as the language's `interface` keyword (too narrow — ordering rules and error modes are part of it even when no type says so), and *boundary* as a synonym for seam.
- Read by the map's detailed-design stage, by `DESIGN-IT-TWICE.md` (whose parallel design agents are briefed with it, so all three name things the same way), and by whatever TDD skill lands next.

## 0.31.0 — 2026-08-18

- **New skill: `/devflow:diagnose <symptom>` — the debugging discipline devflow had no answer for.** Its single rule is the whole skill: **no hypotheses until one command already goes red on this bug.** Catching yourself reading code to build a theory before that command exists is the stop signal, because a theory that cannot be tested is where a debugging session dies. Everything after — reproduce, minimise, hypothesise, instrument, fix, clean up — is mechanical once the loop exists.
- **The loop is built from the project's own commands**, so the user can re-run it tomorrow: `test.run` / `test.integration` for a failing test, `env.up` + `env.health` + `auth.recipe` + `services` for an HTTP call (handed to the `api-tester` agent past ~3 steps, the same way `test-flow` does it), then a CLI with a fixture, a headless browser, a replayed trace, a throwaway harness, a fuzz loop, a bisection harness, a differential run. The loop is done when it is red-capable (asserts **the symptom the user described**, not "did not crash"), deterministic, fast, and runnable unattended — and shown, already run once, with its output.
- **When a person is unavoidable, the conversation becomes a script.** `skills/diagnose/hitl-loop.template.sh` — `step` shows an instruction and waits, `capture` asks and stores, everything captured prints as `KEY=value` for the agent to read as data. It matters because the run after the fix is then the *same* run rather than a similar conversation. Only human steps go in it, never credentials (signing in is a `step`, not a captured value), and the working copy lives outside the repository so one bug's steps cannot end up in a commit.
- **Unstable bugs get a rate, not a repro**: loop the trigger, parallelise, add load, inject sleeps until it is debuggable — 50% is workable, 1% is not. And when no loop can be built at all, the skill stops and says what would unblock it (environment access, a redacted artifact, permission to instrument) instead of hypothesising anyway.
- **Three to five falsifiable hypotheses before testing any of them**, each stating its prediction, ranked and shown to the user first — they re-rank it in one sentence surprisingly often — without blocking if they are away. Probes then change one variable at a time, every debug log tagged `[DEBUG-xxxx]` so cleanup is one grep. Performance regressions branch off: measure a baseline first, logs mislead there.
- **The regression test is written before the fix — but only at a correct seam.** No correct seam is itself the finding: the architecture is preventing the bug from being locked down, so the bug still gets fixed, the gap gets offered as a `/devflow:issue`, and a shallow test that gives false confidence never gets written quietly.
- **The cause lands where it will be read**: in the commit message, and in whatever it contradicts — a map's *How it works today*, a doc mapped in `docs.map` — fixed in the same change. A bug whose cause proves the documentation wrong has just told you the documentation is wrong.
- **`/devflow:task` routes bugs here first**: "this is broken" now starts with diagnosis and continues the task cycle from the cause, instead of implementing against a guess.

## 0.30.0 — 2026-08-18

- **Design it twice, at the stage where the shape gets fixed.** `/devflow:map` produced exactly one design for anything, and a shape written into `design.md` stops being argued with — so the first idea won by default. `skills/map/DESIGN-IT-TWICE.md` builds three in parallel instead: the user is shown the problem frame (constraints, dependencies, a rough sketch that exists to make the constraints concrete rather than to propose anything) and reads it while three agents design against three different constraints — minimize the interface, maximize flexibility, make the most common call trivial; a fourth joins when a dependency crosses a seam.
- **The constraints are a baseline, not a liturgy.** Where one has no bite in this case — flexibility nobody will use, a common case that does not exist — it is replaced by one that does. A constraint nobody needs produces a cosmetic variant, and three cosmetic variants are worse than one honest design.
- **Applies to any shape that is expensive to change**, not just a module's calls: an API contract, how responsibilities split across services, a user-facing flow when the flow is itself the decision. Not to adding a field to an existing call.
- **Compared on three named axes, then recommended — never handed over as a menu.** *Depth* (how much work the interface hides; a shallow design passes the work back to the caller and only renames it), *locality* (where the next likely change lands — one place or fanned out), *seam placement* (what the tests will be able to target). Three options with equal weight hand the work straight back to the user, which is what they were trying to avoid.
- **Losers get one paragraph in `design.md` → *Rejected alternatives*** — the idea, what it cost, why it lost. Full texts die with the session deliberately: a future session needs the reason, and the details would only invite re-opening a settled decision.
- **Offered once, with the price named**, because three design agents are a real spend; a refusal is not re-asked in that effort. No Agent or Workflow tools in the session → one design, and say so.

## 0.29.0 — 2026-08-18

- **One style rule for everything devflow says: `skills/OUTPUT-STYLE.md`.** The complaint that produced it, twice in one session: the questions were unreadable — "axis", "pass", "triage", "orchestrator", "the loop wraps around it". A question the reader has to decode gets answered on what they decoded, not on what was asked, and the wrong answer is then recorded as a decision. The rule binds every message a skill prints **and every file it writes for a person to read** — tickets, specs, `design.md`, handoffs — while leaving code, commit messages, and the skills' own instruction text alone.
- **What it fixes, concretely**: plain words, with the term either replaced or explained at first use (names that *are* the thing — `REVIEW.md`, `git diff`, a ticket id — stay); active voice; 15–25 words a sentence; no word that carries no information; no metaphors for mechanics. Paragraphs of two to four sentences, first words carrying the topic. **Lists only for actual enumerations** — an argument cut into bullets loses the connective tissue that made it an argument. Headings only past two sections, bold at most once a paragraph, no decorative emoji (a fixed marker like `⚠ judgment call` is a label, not decoration).
- **Questions get one fixed shape** — `Question N. …?` then `Proposed: …` on its own line, in the user's language. One question, one decision, each standing alone; three or four per round; a question depending on another open question waits for the next round; the recommendation is a real answer, not a survey. `discuss` now points at the rule instead of carrying its own format.
- **Reports get their own**: outcome on the first line, then what was done and how it was checked, honestly named; where the result lives; one fact once; and the **next action on the last line** — in a terminal the eye rests at the bottom, next to the prompt.
- **Grounded, not invented.** People scan rather than read (79% scan, ~20% of words; scannable rewrite scored 47% higher — Nielsen Norman Group); front-loading and everyday words with full nuance kept are GOV.UK's content principles ("open it up, do not dumb it down"); brevity, intentional emphasis, and last-line placement come from the command-line guidelines at clig.dev. The cap on structure answers a documented habit of language models — headings, bullets, and bold produced past anything asked for, until the shape of an answer stands in for its content. Sources are linked in the rule file.
- Wired into the seven skills that do the talking: `discuss`, `map`, `review`, `handoff`, `research`, `task`, `build` — each reads it before its first message.

## 0.28.0 — 2026-08-18

- **`/devflow:review` gains a second, independent check: Requirements.** Until now the loop judged one thing — is the code written the way this project writes code. Whether the diff implements what was actually decided had nothing to compare against; now `design.md`, the map ticket and its acceptance checklist exist, so the loop closes: designed → implemented → checked against the design. A change can pass one check and fail the other — perfect style building the wrong thing, or exactly the right thing in a style the project rejects — which is why the two are **reported side by side and never merged or reranked**: merged, the louder axis hides the quieter one, and the quiet one is Requirements.
- **The checks do not see each other.** Requirements runs as a subagent with a clean context, given the decisions and the diff and nothing else, so it never learns to read the code through a style reviewer's eyes; Standards runs in place as the built-in `code-review` with the project rubric, and is never told what Requirements found. Both are in flight before either report is read.
- **Where Requirements takes its source**, first hit wins: the map ticket plus the `design.md` sections it names and the effort's *Out of scope* → a tracker key in the commit messages → a path passed as an argument → ask. Nothing recorded and the user confirms there is no spec → the check says "nothing to compare against" in one line rather than passing silently. It reports three classes, each citing the source line: required but missing or half-done, present but never asked for, and looks implemented but does not do what was decided.
- **A Requirements finding has three outcomes, and picking the right one matters more than the fix**: the code is wrong → fix it; the decision was wrong → **write the question into the ticket it concerns and stop**; the departure was deliberate → one line in the ticket saying so, or the next reviewer reads it as a slip and "fixes" it back. The middle one is the load-bearing rule: a decision taken while implementing ticket 1 that touches ticket 2 also reaches ticket 3, which depends on 2 — and re-planning that chain from inside ticket 1 plans it without what ticket 2 will know when it starts. `task` and `build` carry the same rule.
- **The smell baseline (`skills/review/SMELLS.md`) now runs in every project, always** — fourteen shapes from Fowler's chapter 3, each reported as a judgment call. A documented project rule no longer silences a smell; it turns it into **one question**, asked once: is this deliberate, or is it what nobody had time to undo? A project can be uniformly badly written, and the user only ever finds out if someone points at it. "Yes, deliberate" is offered a line in the repo's `REVIEW.md`, so it survives past this session instead of being re-litigated by the next one. Anything tooling already enforces is still skipped.
- **`task` and `review` stay separate on purpose.** A task runs its own single check against what was decided (or, with nothing recorded, against the plain bar: correct, and doing the job it was written for) and triages it in its own close-the-loop gate. `/devflow:review` remains the deliberate end-of-work review — a gated loop nested inside another gated loop buys nothing. `build` gets the same three classes spelled out in its self-verification step, where the orchestrator was already doing the work by eye.

## 0.27.0 — 2026-08-18

- **`handoff` gains a second mode: handing unfinished work to the next session.** Until now it only produced a review handoff — a report for the human once the work was done. Stopping in the middle had no support at all, and everything the session had learned died with it. The skill now picks by whether the work is finished: **finished → review handoff** (unchanged, risk-ranked, with two-minute re-checks), **unfinished → work handoff**, whose reader is the next session and whose job is to spend that session's first minutes on continuing rather than re-deriving.
- **The unit is the ticket, not the branch.** A ticket handoff is a `## Handoff` section appended to the ticket file itself — state belongs to the ticket, the next session opens it anyway, and one file cannot drift from another; `Status: in progress` stays as the live-work marker. A whole effort parked mid-way goes to `<maps.dir>/<effort>/HANDOFF.md`, overwritten each time: one current picture, not an archive of stopping points. Work with no map behind it proposes a path and lets the user pick.
- **Six things and nothing else**: the goal in two lines; what is done and **where it lives — committed versus sitting in the working tree** (the distinction whose absence ruins a handoff); the exact stopping point, down to the file and the next action you would have taken; **what did not work** and why, so the next session does not re-walk the dead ends — usually the most valuable section and the easiest to skip; decisions made along the way that are not yet in the design, which must then be moved *into* the design rather than left in a relay baton; what is left, plus which skills to call. Everything already recorded is referenced, never copied.
- **Uncommitted work is settled, not mentioned.** A dirty tree does not travel: next session on this machine → say so and name the files; anywhere else → offer a WIP commit marked as a checkpoint, since uncommitted work simply will not arrive. Handing off silently over a dirty tree is forbidden — the next session finds files it cannot explain and stops trusting the rest of the document.
- **Wired into the skills that stop mid-work**: `task` writes one when a ticket is abandoned before it is done, `build` writes one when an iteration cannot finish its ticket, `map` writes one when a whole effort is parked.

## 0.26.3 — 2026-08-18

- **discuss: the code is context, not authority.** Two rules that look opposed and are not. Questions must be **grounded in the project** — asked in its own terms, naming what is already there ("services A and B already verify a Keycloak JWT — same path here, or different requirements?"), because a generic question burns the user's patience and a grounded one proves the homework is done. But **existing code answers *what is*, never *what should be***: a pattern is not a norm because it is present, and an agent that only validates the status quo is worth less than one that argues with it.
- **When the better answer does not fit the current code, the axis is the cost of divergence, not "better".** Silently following a bad pattern and silently "improving" one are the same failure — a decision the user never made, in code they maintain. The agent now names three things (how the project does it today, what it would do instead and why, what the divergence costs) and puts three options to the user: follow the existing pattern with the flaw recorded as known; do it the new way here and migrate the rest, with that migration scoped so its price is visible before the choice; or do it the new way here only and carry two ways as written-down debt. Push for the break when the decision is hard to reverse, when the existing pattern is a live source of bugs, or when the new code will outlive the old — leave it alone when the pattern merely offends taste.
- **A deliberate divergence is recorded, not just decided.** `design.md`'s rejected alternatives now carry it along with the cost the user accepted, and the implementing ticket says so in one line — otherwise the implementer "restores consistency" on their own and the reviewer reads the departure as a slip.

## 0.26.2 — 2026-08-18

- **discuss: dig for the intent, not just the answers.** The skill checked that every fork was closed; it never checked that the *intent* was understood — an empty question list and shared understanding are not the same thing. Three mechanics, now their own section. **Every vague qualifier is a question**: "authentication that suits this project" carries its whole meaning in *suits*, a word that means nothing until this user fills it in and that the agent otherwise fills in with its own default (same for simple, proper, standard, "like everyone does it"). **Ask why, then distrust the first why** — "because it's simpler" is a proxy, not a reason; behind it sits a deadline, an unfamiliarity, or an unwritten requirement, and it is the reason, not the proxy, that future decisions get checked against. **Test an answer with a scenario that would break it** — not speculation, a concrete near future (a second consumer, a second provider, a teammate joining, this failing at 3am): planned means the decision changes now, not planned means it is recorded as a non-goal. Offering two or three real alternatives is reframed as mapping the space rather than making the user shop — how they react to a specific option surfaces the constraint they never mentioned.
- **The convergence bar moves from "no new decisions" to shared understanding.** Before writing the spec, the agent restates the intent in its own words — what the user is after, why the chosen shape serves it, what it deliberately leaves out — and gets that confirmed. Not decisions read back: the picture they add up to. A *why* that cannot be stated without hedging means the decision was never understood.
- **`map` points its charting phase at the same rule**, so a foggy qualifier in a goal gets interrogated instead of silently resolved.

## 0.26.1 — 2026-08-18

- **discuss: prose is the default instrument, menus are the exception.** Field feedback from the run that designed the map layer: across thirteen questions the user answered three outside the offered options, because the real answer carried a condition no label could hold ("archive it, but keep the archive out of commits too"). A menu buys seconds and spends nuance — the user picks the nearest label, the agent records it as a decision, and the gap between "nearest" and "right" only surfaces after implementation. Questions are now asked as numbered prose, each with a recommended answer so a round still settles in a few words; `AskUserQuestion` is reserved for a fork that is genuinely enumerable AND exclusive, where the whole answer fits in a short label. Two tells that a menu is wrong, written into the skill: the option *description* is carrying the real content, or an answer outside the list would not surprise you. This continues 0.24.1 (which added prose alongside menus) by settling which of the two leads.

## 0.26.0 — 2026-08-18

**Breaking**: `/devflow:ralph-plan` and `/devflow:ralph-build` are gone, the manifest's `ralph:` section with them. Planning now belongs to `/devflow:map` end to end; the autonomous loop survives as `/devflow:build`, which grinds a map's tickets instead of a TODO list. Existing projects: `/devflow:update` adds `maps:` and flags the orphaned `ralph:` section — an unfinished `TODO.md` has to be re-cut as map tickets by hand, or kept as a plain notes file.

- **`/devflow:build` replaces the ralph pair.** With planning in the map, a second planner had nothing left to do, and `ralph-build` was inheriting a name whose other half no longer existed. `build` is the same discipline over map tickets: pick the first ticket whose blockers are done, implement in a fresh-context subagent, verify the diff and the acceptance checks yourself, commit the code, mark the ticket done, one ticket per invocation under `/loop`. Two things changed beyond the source of work: **a gap in the design blocks the ticket instead of being guessed at** (the whole point of having designed it first), and only code is committed — tickets live outside git, so the old "code plus checkmark in one atomic commit" is now just "code".
- **`ralph-stop-gate` → `stop-gate`, on a new signal.** The gate used to fire on a dirty `TODO.md`, which no longer exists in git. It now fires on a ticket marked `Status: in progress` plus a dirty working tree — an iteration that implemented something and is stopping without committing it. Both `/devflow:build` and `/devflow:task` set that marker when they pick a ticket up. The new signal is strictly narrower than the old one: with no ticket in flight, an interactive session ends mid-edit exactly as before. Nine committed regression cases cover it, including the one that matters — map edits are invisible to git, so planning never trips the gate.
- **Manifest**: `ralph:` is gone; `maps:` gains `specs_dir` for standalone specs written outside any map. `session-digest` drops its ralph line (the map line replaces it), `config` reports efforts instead of a TODO, `issue` records keys against blocked tickets, `init` records deferred Tier-2 gaps as tickets in a `setup` effort.
- **A finished effort is archived, not left lying around** — but only after what outlives it has been carried out: rejected alternatives, sharpened terms, and stale-or-newly-true recon go to the project's own docs first, then the directory moves to `<maps.dir>/.done/<effort>/`. Out of sight, out of the digest, still on disk. Deleting is the user's call, never the default.

## 0.25.0 — 2026-08-18

- **New skill: `/devflow:map <goal>` — the design layer devflow was missing.** The failure it closes: an agent invents implementation details not because it lacks context on the code, but because the work was never taken apart before it started. Real development runs idea → recon → requirements → concept → spec → **detailed design** → slicing → implementation; devflow squeezed three of those stages into `discuss` and had no detailed-design stage at all — precisely where interfaces, seams, data shapes, and edge behavior get decided silently. The map is a **decision map in files**: `map.md` as an index (destination, how-it-works-today recon, one gist line per resolved decision, the fog not yet chartable, what was ruled out of scope) plus one file per decision ticket. Two ticket types: `research` (a fact from outside — closed by the agent alone, parallelizable) and `grilling` (the user's judgment — closed only in live conversation, never answered on their behalf). Tickets carry `Blocked by` edges; the **frontier** is what is open, unblocked, and unclaimed, worked one decision per session so a fresh window decides rather than a crowded one. **Fog of war is deliberate**: chart only what you can phrase sharply now — the test is whether you can state the question, not whether you can answer it. When the frontier empties, the map emits three artifacts: `spec.md` (what and why), `design.md` (how exactly — interfaces and seams, data shapes and contracts, behavior at the edges, rejected alternatives), and vertical-slice `tickets/` with acceptance checklists. Reference files alongside the skill hold the formats and the slicing rules, including **expand–contract** for wide refactors no vertical slice can land green.
- **Maps never enter git — at any footprint.** `.devflow/maps/` is excluded via `.git/info/exclude`, never `.gitignore` (that file is committed and the line itself would expose a private draft). A planning draft is the author's thinking, not team documentation; the price, stated plainly, is that maps live on one machine and backing them up is the user's job.
- **`discuss` becomes both a map instrument and a standalone command.** From the map it resolves one decision ticket and hands the answer back — **the map writes the spec, not discuss** (two authors guarantee two drifting versions). Standalone it owns the full protocol as before. Interviewing gains three mechanics: rounds now follow the **decision tree and its frontier** instead of a fixed axis checklist (a question depending on another open question belongs to a later round); prose questions are numbered and carry a recommended answer, so a round can be settled in a few words; and **facts are the agent's job** — an environment fact is dispatched to a subagent instead of asked, blocking only the questions downstream of it.
- **`task` becomes the executor of a ticket.** It now accepts a local ticket path alongside a tracker key, reads the sibling `design.md`/`spec.md` for the sections its ticket names, and does **not** re-plan what the map already decided — a gap in the design is a question for the user, never license to decide. It checks `Blocked by` before starting, ticks the acceptance checklist and sets `Status: done` on close, then names the tickets that just became unblocked. Plain-text arguments still work but now say what they mean: this task was never designed — offering `/devflow:map` first, and recording the user's override in the close-the-loop report if they proceed anyway.
- **`session-digest`: a line for an open map**, printed only when actionable, like the existing ralph and manifest lines — unresolved decisions plus how many are takeable right now, then a nudge when every decision is resolved but nothing has been cut yet (the map still owes its three outputs), then the count of remaining implementation tickets, and silence once the effort is finished. A map lives outside git, so nothing else would remind of it.
- **`init` / `update` / `doctor`**: the manifest gains a `maps:` section (`dir: .devflow/maps`); init creates the exclude entry unconditionally, before any map exists; update finishes what a new section implies outside the yml; doctor checks that maps are excluded, fails hard on a planning draft already tracked by git, and lists open efforts informationally.
- **Principle made explicit: local by default, tracker optional.** Maps, decisions, and tickets are files; publishing implementation tickets to a tracker is offered once, only when one is configured, and the local file stays the source of truth. A project without a tracker is the supported default, not a degraded mode.
- **Deliberately NOT done**: ralph (`ralph-plan`, `ralph-build`, the stop gate) is untouched and stays as the autonomous path — the map answers *what should be built*, ralph grinds *a known list*; a `prototype` ticket type; decision tickets on a real tracker; recon as its own ticket type (it is a map section instead, so the artifact exists without the extra entity).

## 0.24.1 — 2026-07-16

- **discuss: prose dialogue is a first-class instrument, not a violation.** Field feedback from the first live run: menu-only interviewing is too shallow — AskUserQuestion holds four short labels, and a real discussion doesn't fit in them. The interview now alternates two instruments: **menus for honestly enumerable forks** (unchanged: options + recommendation, pick in seconds) and **free-text questions for open ground** (the user's vision, motivations, "walk me through it" — 1–3 pointed questions at a time, each tied to something just said). New obligation: **follow up on every answer** — an answer that opens new ground, contradicts an earlier one, or hides an ambiguity gets chased in the next round instead of marching down a checklist. The old blanket ban on free-text questions is narrowed to what it actually meant: no walls of ten unstructured questions.

## 0.24.0 — 2026-07-16

- **New skill: `/devflow:discuss <idea>` — pre-implementation discussion.** Closes the gap *before* ralph-plan and task: the user has a picture in their head, the agent can't read minds, and every silently-made decision is a future "это не то, что я имел в виду". The skill interrogates in rounds (AskUserQuestion, 2–4 per round, options with a recommendation — never free-text question walls), but only on real forks: a question earns its slot when different answers produce different plans AND nothing already answers it. **Two grounds**: a feature in an existing repo (homework in the code first; axes: scope/non-goals, edge behavior, data contracts, integration, quality bar) and a **greenfield idea with no repo at all** ("хочу приложение для фитнеса"; axes: audience and pain, core loop, MVP cut vs explicit LATER, platform/stack, data, distribution). Three mechanics beyond Q&A: the **"I don't know" ladder** (propose fitting options with trade-offs → if none credible, narrow with follow-up questions → else an honest open question + `/devflow:research`, never a silent pick or fake inline research), **contentious calls** (the agent argues its case once with trade-offs — participant, not stenographer; the user's decision is final and the losing option is recorded), and the **assumption ledger** (everything the agent would still decide silently becomes an explicit "unless you say otherwise" list the user confirms). Output: a spec/concept file — in `ralph.specs_dir` with a manifest, wherever the user picks without one — with a decisions log, confirmed assumptions, non-goals, and open questions; consumed by `/devflow:task` (small), `/devflow:ralph-plan` (large), or `init`+`ralph-plan` (greenfield). Hard rule: no implementation inside the skill — "it's clear enough, let me just build it" is the exact failure it exists to stop.
- **Docs**: README situation table, GUIDE command reference and entry-by-task-size table gain the discuss row.

## 0.23.0 — 2026-07-08

- **`swarm` mode — opt-in multi-agent Workflow across four skills** (`review`, `research`, `test-flow`, `sync-docs`). The word `swarm` in a skill's arguments is the user's explicit opt-in to the expensive parallel path — the same contract as the cloud-billed `/code-review ultra`, but local: the skill announces the plan and token cost, fans out via the harness Workflow tool, and where that tool isn't present degrades to the skill's existing single-threaded or Agent-based path rather than failing. Rationale: a few skills gain real quality from *deterministic* orchestration (per-dimension pipelines, barriers, adversarial verify) that a model-driven single pass leaks — but tacit fan-out on every invocation would betray devflow's guardrail-first posture, so it stays behind an explicit keyword, never a default.
  - **review**: `swarm` runs the review pass as a pipeline of per-dimension finders (correctness/security/perf + every REVIEW.md check), each finding then confirmed by adversarial verifiers (skeptics prompted to refute; survives on majority-confirm) before entering the same triage→fix→re-review loop. Distinct from `/code-review ultra` — that runs billed in Anthropic's cloud; `swarm` fans out inside the session.
  - **research**: upgrades the existing behind-a-cost-gate fan-out to a deterministic Workflow — multi-modal sweep (angle × source-type), contrarian as its own parallel stage, adversarial claim verification before a confidence grade, loop-until-dry. Now three depths: `quick` / full / `swarm`.
  - **test-flow**: `swarm` + several flows runs a suite in parallel — shared env/auth established once in the main session, one agent per flow, fixture-colliding flows serialized rather than raced. A single flow stays on the api-tester path (fan-out buys nothing).
  - **sync-docs**: upgrades the bucket fan-out to a verified pipeline — each claimed 🐛 (doc reveals a code bug) is re-checked by an independent agent before the digest; an unsubstantiated one is downgraded to 📝 or dropped with a note. Confluence stays in the main session (no MCP inside Workflow agents).
- **Docs**: README and GUIDE tables document `swarm` alongside `quick`, so the mode is discoverable and `sync-docs` won't flag it as drift.
- Deliberately NOT added: `swarm` on `task`/`issue`/`doctor`/`handoff` (nothing to parallelize there); Workflow as any skill's default (opt-in only, by design).

## 0.22.3 — 2026-07-02

- **ralph-build: loop end = handoff** — when a run finishes (TODO fully checked, or stopped on blockers), the loop offers a review handoff for the whole task branch, with the TODO's `⚠ judgment call` notes feeding the 🔴 section. Closes the last scenario where the user had to remember to ask "что мне проверить" after an autonomous run — inside the task cycle the handoff was already built in, outside devflow the standalone skill auto-invokes on intent.

## 0.22.2 — 2026-07-02

- **session-digest: conditional state lines** — the digest gains two lines that print ONLY when actionable: an unfinished ralph TODO (`N unchecked, M blocked — ralph-build continues; blocked items need the user`) and unconfirmed manifest markers (`N UNVERIFIED, M TODO — /devflow:revalidate`). Rationale: started large work and unsettled settings were invisible at session start until asked; and a line that appears only when something needs attention gets read, while an always-on line gets skimmed — so the unconditional part stays at exactly 3 lines, and a clean project adds nothing. Deliberately NOT added: env/auth/test commands and tracker details (skills read the manifest on demand — a context copy would drift from the file), git status (the harness already provides it), code style (CLAUDE.md's job).

## 0.22.1 — 2026-07-02

First execution of `tests/INIT-CHECKLIST.md` (react-vite + monorepo-mix, scripted subagent dry-runs): **both fixtures PASS every criterion** — correct type detection (incl. the monorepo one-root-manifest rules), no irrelevant interview questions, honest `# UNVERIFIED` on every unproven claim, clean machine-truth scan, correct INIT.md lifecycle. The runs surfaced 7 friction points in the init skill text (4 found independently by both agents); all fixed:

- **Step 4/5 ordering contradiction removed**: step 4 now *drafts* the manifest, step 5 reviews and *writes* — "generate, then 'before writing present a table'" was unfollowable as numbered.
- **Protected-surface question added to the interview**: the `# none` marker's condition said "exploration + interview establish…", but the interview had no auth question — the condition was unsatisfiable through the listed questions. Now asked explicitly (confirm exploration's finding, not open-ended).
- **Missing CLAUDE.md case specified**: create a minimal one with ONLY the devflow section, recommend built-in `/init` for the rest (was ambiguous between "write now" and "skip entirely").
- **Deferred Tier-2 gaps persist**: postponed gap plans are recorded in `ralph.todo` before INIT.md is deleted — they used to die with the progress file, the exact knowledge loss it exists to prevent.
- **`# UNVERIFIED` scope clarified**: covers every claim not proven live — health URLs and framework-default ports included, not just command fields.
- **Overlay ignore entry is unconditional**: `.devflow/project.local.yml` gets its ignore entry even when the overlay is empty today — it was mandated only inside the related-repos rule, leaving a future overlay one forgotten entry from being committed.
- Empty git history → git-flow questions go open-ended with proposed defaults (nothing to "confirm" on a young repo); template: a foreground-only dev server legitimately has `down: ""` with a comment.

## 0.22.0 — 2026-07-02

- **guard: uncommitted work is not disposable** (Guard 5): `git reset --hard` and forced `git clean` (`-f`/`--force`, any flag cluster) are blocked in devflow projects — the working-tree analog of the volume policy, same `DEVFLOW_ALLOW=1` escape on explicit user request. Soft/mixed resets and `git clean -n` dry runs pass. 9 new regression cases (43 total).
- **doctor full: remote base-branch protection** — the local guard is a floor on this machine; doctor now checks the server-side wall: GitHub (`gh api …/branches/<base>/protection`) or GitLab (`glab`), recommending protection when absent; no CLI/permission/other remote → honestly skipped, never guessed.
- **ralph-build: blocked items must not rot** — when the loop stops on blockers, each `## Blocked` item is offered to `/devflow:issue` (the recorded question + what the iteration learned is the finding), filed keys noted back into the TODO; without a tracker the final report lists them as the user's decision queue.
- Deferred by choice: `on_done: pr` (auto-created MRs) — later; Windows hooks — later.

## 0.21.0 — 2026-07-02

Anti-drift and self-checking: conventions in context from token zero, live validation on demand, the plugin lints itself.

- **New SessionStart hook `session-digest.sh`**: every session opened in a devflow project starts with the load-bearing manifest facts in context — base branch (and that history on it is hook-guarded), branch/commit patterns, the persistent-data policy. Skills reload their rules only when invoked; the digest pins the core conventions between invocations — deterministic, fail-open, silent outside devflow projects. Covered by `tests/session-digest.test.sh`.
- **New skill `/devflow:revalidate [section]`**: init's mandatory live validation, runnable on demand — executes every filled command-like field (env.up + health, auth recipes, tests on confirmation, `db.snapshot`, service host ports) and updates markers in place: pass → `# VERIFIED <date>`, fail → `# UNVERIFIED — reason` with the value kept (fixing values is an approved follow-up, never a silent rewrite mid-validation). `db.restore` is never executed. Division of labor stated: doctor is read-only and finds; revalidate executes and records. Precondition budget applies (~10 tool calls per field). Doctor and config now point their UNVERIFIED listings at it.
- **Plugin self-lint `tests/lint.test.sh`** (runs in CI via `tests/run.sh`): skill/agent frontmatter complete, hooks.json commands exist and are executable (0.9.1's exec-bit regression is now caught mechanically), `${CLAUDE_SKILL_DIR}` references resolve (0.18.1's dangling-path class), the manifest template parses as YAML, keys the hooks grep-parse (`base_branch`, `branch_pattern`, `commit_pattern`, `todo`, `footprint`) stay unique in the template, and plugin.json's version matches the latest CHANGELOG entry.

## 0.20.0 — 2026-07-02

Analysis-driven release: the hook suite becomes committed and CI-enforced, base-branch protection covers all local routes, review skills read the canonical REVIEW.md, committed files get a personal-data floor, docs sync learns Confluence, init gets fixtures and a monorepo story.

- **Committed regression suite + CI**: `tests/guard.test.sh` (34 cases) + `tests/stop-gate.test.sh` (6 cases) — the 0.12.0/0.18.1 adversarial cases plus the new guards, dangerous strings assembled at runtime, disposable sandboxes. `.github/workflows/ci.yml` runs shellcheck + the suite + JSON manifest validation on every push/PR. Doctor's layer-1 self-tests now run this suite (manual probes remain as the pre-0.20 fallback). The 0.18.1 "regression suite green" existed only in that session's context — now it's in git.
- **guard: pushes and merges into base blocked** (Guards 3–4): explicit refspecs targeting base (`push origin <base>`, `HEAD:<base>`, `feature:<base>`, `:<base>` deletion, `--delete <base>`) — checked textually, works outside a repo; bare `git push` while ON base; `git merge`/`git cherry-pick` while ON base. `git pull` on base stays allowed (the sanctioned base update; known limit: `git pull origin <feature>` slips past). Fail-safe trade-off: pushing another ref while standing on base is also blocked — `DEVFLOW_ALLOW=1` covers the legitimate case. Shared helpers (`git_cmd_re`, `git_target_branch`) dedupe the `-C`-aware anchor logic Guard 2 already had.
- **REVIEW.md is part of the review rubric**: the built-in code-review reads repo-root `REVIEW.md` as its highest-priority instructions (severity, nit caps, skip rules, repo checks) — devflow's review loop and task's review step now load it explicitly alongside CLAUDE.md, findings may cite it, its skip rules apply to triage. init mentions it as the canonical place for custom review rules (mention, don't author); GUIDE's rules-layer table gets the row.
- **Machine-truth scan** (doctor layer 2 + init validation rule): committed devflow files (`project.yml`, `.claude/settings.json`, CLAUDE.md section) are scanned for machine/person-specific values — absolute home paths, `$HOME`, the local username, personal email. Hit → move to `project.local.yml` / `settings.local.json`. The related_repos identity/path split generalized: it applies to every committed field (env/test/db/auth commands, permission allowlists), prefer repo-relative commands. Complements the secret scan: secrets were covered, personal data wasn't.
- **Confluence sync** (optional, via the same Atlassian MCP as Jira): `docs.map` entries may carry a `confluence` page (`{ file: …, confluence: <id|url> }`), site/space in `docs.confluence`, asked during init when the tracker is Jira. task's knowledge-sync proposes page updates for touched flows; sync-docs audits mapped pages claim-by-claim and author mode can publish (Confluence stays in the main session — subagents have no MCP tools). All page mutations are outward-facing: draft → approval, never allowlisted (init rule + doctor check extended), updates stamped with the commit ref, MCP-unavailable reported as skipped — never as accurate.
- **Init verification fixtures**: `tests/fixtures/` — six skeleton repos (dotnet-webapi, react-vite, flutter-app, angular-app, terraform-infra, monorepo-mix) + `tests/INIT-CHECKLIST.md` with per-fixture expected type/fields/questions and pass criteria (incl. "no UNVERIFIED markers on a fixture = hallucinated validation = failed check"). Run after changes to the init skill or the template.
- **Monorepo (`type: mixed`) story**: init identifies packages/areas first (workspaces, nx/turbo/melos, solutions), explores each per its own type; ONE manifest at the repo root — whole-stack `env.up`, all HTTP surfaces in `services`, aggregate `test.run` with per-package commands in comments; genuinely independent areas → suggest onboarding a subdirectory as its own project. Template documents the shape.
- **Confirmed absence beats ambiguous emptiness — `# none` marker for auth**: `recipe: ""` could mean "no protected surface" (configuration) or "nobody filled it" (gap) — indistinguishable, against the manifest's own verified-vs-unverified ethos. Now init writes `recipe: ""  # none — no protected surface` once the answer is confirmed; config renders "none (confirmed)" vs "not configured (never asked or deferred)"; doctor: marker = ✓, bare empty + HTTP services listed → suggest settling it; test-flow/api-tester: marker → skip auth confidently, no marker + a 401/403 → reported as a manifest gap, never improvised around.
- Windows support explicitly out of scope for now (hooks are bash) — revisit later.

## 0.19.1 — 2026-06-12

First field run of `/devflow:research` (3 subagents, 26–40 tool calls each, ~175k tokens) — quality was right, the spend was uninformed consent. Searches dominate research cost regardless of model/effort, so depth becomes an explicit, user-controlled lever:

- **Cost gate before fan-out**: 3+ angles → the skill announces the plan (angles, subagent count, that this is the ~100–200k-token path) and asks full vs quick before spawning. Single-angle questions skip the gate.
- **Subagent budget ~15 tool calls** (precondition-budget pattern): budget spent → synthesize from what was gathered and name what stayed uncovered; return compressed sourced conclusions, never page retellings.
- **`quick` mode** (`/devflow:research quick <q>`): inline, no subagents, ~8–10 searches, contrarian pass shrunk to one query — and therefore every finding must carry its honest (mostly weaker) confidence grade. For low-stakes questions, never for irreversible decisions; full stays the default.

## 0.19.0 — 2026-06-12

The human's bottleneck is verifying agent work, not producing it — handoffs now spend the reviewer's attention where the risk is. Practices borrowed from fields where the reviewer's miss is expensive: risk-based audit sampling (review effort proportional to risk), structured medical handoffs (fixed sections make omission visible), and the two-minute verifiability rule.

- **New skill `/devflow:handoff`** — the format authority: 🔴 judgment calls + auto-red changes (migrations, auth, data mutation, contracts, concurrency — classified by closed rules, not self-assessment) / 🟡 derived-never-executed / 🟢 mechanical as a count / "verify in 2 minutes" with commands actually run and their observed outputs. All sections always present (empty = one honest line); honest limit stated: only the re-checks are falsifiable, the rest is self-assessment by the model that did the work. Standalone use covers work done without devflow skills or by another agent (then judgment calls are reconstructed from the diff and flagged as weaker).
- **task**: close-the-loop presentation renders as a review handoff (format referenced from the handoff skill, not duplicated).
- **ralph-build**: TODO result notes must record forks — `⚠ judgment call: chose X over Y`; after an autonomous run, `grep ⚠` over the TODO surfaces every decision the loop took without the user.
- **test-flow / api-tester**: verification depth per step (response shape / status code only / side effects) — a status-only ✅ must declare itself; test-flow also names scenario-mapping interpretation choices.
- Not touched by design: sync (✅/🔧/❓ classification already is an attention map), research (confidence grades already are the handoff), review (triage already surfaces judgment calls), doctor/config/init/issue (deterministic or gated — a handoff block there is ritual noise).

## 0.18.1 — 2026-06-12

Second cold adversarial review (10 findings, all with reproductions) — all addressed:

- **guard coverage**: `docker system prune --volumes` and `docker compose rm -v` (any flag cluster) now blocked; `git -c k=v commit` no longer slips past the base-branch guard (interleaved `-c`/`-C` runtime options matched); `DEVFLOW_ALLOW=1` works with leading whitespace. Full regression suite green (15 cases, incl. no-overmatch checks).
- **`${CLAUDE_PLUGIN_ROOT}` in skill bodies** replaced with `${CLAUDE_SKILL_DIR}/../..` — the former is substituted in hooks.json but not in skill content; skills relied on model improvisation to find the plugin root (worked in practice, was not deterministic).
- **secret scan mechanics**: detect with `grep -lE` / `grep -nE … | cut -d: -f1`, never bare `grep -n` (whose output echoes the secret); pattern list extended (connection strings with inline passwords, private key blocks) and marked non-exhaustive — doctor and sync-docs aligned.
- **footprint:local seam closed**: the overlay's ignore entry goes to `.git/info/exclude` in local mode, never a committed `.gitignore` line.
- test-flow: numbering fixed, precondition budget now explicit on the inline (non-HTTP) path too.
- **honest limits told fully** (README + guard header): multi-line commands and state-changing compound commands (`checkout main && commit`) are past the floor; dangerous literals in harmless arguments block safely; "physically prevented" softened to "deterministic guard". Accepted as designed: the false-positive trade-off (doctor's registration test depends on it); no DEVFLOW_ALLOW hint added to block messages — the bypass stays user-initiated only.

## 0.18.0 — 2026-06-12

Lessons from a long-running session: preconditions get budgets, drafts get a deterministic floor.

- **Precondition budget in test-flow / api-tester**: environment, auth, and fixture data are preconditions, not the mission — ~10 tool calls of honest effort, then STOP and report the gap as a finding (broken recipe step, missing fixture, manifest gap) with what would fix it. An hour of auth archaeology is a failed run even if a token eventually appears. The manifest recipe is the ONLY auth path tried — no exploring alternative grants. Stale-binary awareness: a green step against an old build is a false verdict.
- **`auth.user_recipe`** in the template: optional second recipe for a token AS A SPECIFIC USER (authorization_code/PKCE, form login, seed account) — for identity-dependent flows (ownership, role-gated transitions) when the main recipe is service-level. Empty + flow needs it → manifest gap, derive it with the user.
- **Tracker mutations never allowlisted** (init permissions rule + doctor check): skills are advisory and long sessions drift past them — a real session created a Jira issue with no draft shown, bypassing the issue skill entirely. The permission prompt on an un-allowlisted create/edit/transition/comment/link call is the deterministic "show the payload, ask first" floor; doctor flags such tools in allowlists, read-only tracker tools remain fine. Known limit: permissive session modes (auto-approve) trade this floor away.
- test-flow: fixture preconditions checked before execution; missing test data → options (seed / API setup / targeted edit), chosen with the user.

## 0.17.2 — 2026-06-12

- sync-docs author mode: un-ignoring must never widen exposure. When an ignore rule is removed so mapped docs can be committed, every file it was protecting that stays local gets its own targeted ignore entry in the same edit, verified per file with `git check-ignore`. (Field run removed a whole-directory ignore and left a credential-bearing doc merely untracked — one `git add -A` away from a leak.)

## 0.17.1 — 2026-06-12

- sync-docs author mode: git status of a doc is determined PER FILE (`git ls-files --error-unmatch`, then `git check-ignore`), never generalized from a directory listing — first field run declared 9 docs "all committed" when 6 of them were gitignored and invisible to every clone. Plus a mandatory secret scan before any doc is mapped or proposed for commit: a hit excludes the file until cleaned, reported by location only (the same run nearly proposed committing docs with live connection-string passwords).

## 0.17.0 — 2026-06-12

Docs become a guaranteed knowledge layer: devflow now ensures mapped docs exist and are team truth, not just audits them when they happen to be there.

- **sync-docs author mode**: empty `docs.map` (or mapped files missing) → inventory existing docs (classifying contract / reference / personal note, checking git status of each), propose a map that keeps the project's own names and locations, and for gaps generate a canonical skeleton shaped by `project.type` (architecture / environments / contracts / testing) — written FROM CODE with the same claim-by-claim discipline as auditing, as ordinary committed project files. No invented content, no devflow-private formats.
- **Team-truth rule for mapped docs** (doctor): every `docs.map` file must exist and be git-tracked — an untracked or gitignored mapped doc is one person's notes that teammates never see. `footprint: local` exempt by design.
- init step 8: propose the map from docs found during exploration (tracked contracts only), point to author mode when there's nothing usable; never blocks init.

## 0.16.0 — 2026-06-12

Machine-local overlay: team truth and machine truth no longer share a file.

- **New `.devflow/project.local.yml`** — sparse overlay with the same structure as the manifest, gitignored, overlaid on top (local wins). For values true only on one computer; the committed manifest stays valid for every teammate.
- **`related_repos` split**: identity (`url`, `branch`, `relationship`) is committed; the absolute local `path` lives in the overlay under the same key. An absolute path in a committed manifest was a bug waiting for the second contributor. Solo projects may still keep `path` in the manifest.
- sync resolves the path overlay-first, asks once if missing and writes the answer to the overlay (never the manifest), offers to clone from `url` when the repo isn't on this machine.
- config renders overlay values marked `(local)`; doctor treats "identity present, not cloned here" as ℹ, and flags a committed `path` in a multi-contributor repo.
- init writes paths to the overlay from the start and adds the `.gitignore` entry.

## 0.15.3 — 2026-06-12

- doctor: mandatory secret scan in layer 2 — manifest and `.claude/settings*.json` checked for credential patterns (Atlassian/GitHub/GitLab/AWS tokens, basic-auth in curl, literal Bearer). A hit is ✗ critical with a revocation demand: a secret that sat in plaintext is compromised, deleting the line is not enough. The secret itself is never printed, not even a prefix — pattern name and location only. (The check existed only as model improvisation — it caught a live token in the wild; now it's deterministic protocol.)

## 0.15.2 — 2026-06-12

- issue skill: no area/type prefixes in issue titles (`[BACKEND]`, `МОБА:`, `Bug:` …) — routing lives in `tracker.labels` and the issue type; a title prefix duplicates them and pollutes search and boards.
- config skill: auth verification status is read from the manifest's `# UNVERIFIED` markers, never invented from session state — config is a viewer of recorded facts, and "not run in this session" is not UNVERIFIED (it would mark every validated recipe stale in every fresh session).
- template: `services.*.port` is explicitly the HOST port. A service behind a gateway with no host mapping (compose `expose`, k8s ClusterIP) records `port: ""` plus the gateway route in a comment — never the container-internal port (found in the wild: init recorded a container's `:80` as a host port, sending agents to the gateway instead).

## 0.15.1 — 2026-06-12

- issue skill: relations become REAL tracker links ("link, don't mention"). Related issues are listed in the draft with a proposed link type, created via the tracker's link mechanism right after filing (Jira `createIssueLink`, GitHub cross-reference, Linear relation), and reported; a failed link is said out loud, never silently dropped. A textual "related to ABC-12" is prose — boards, filters, and automation only see links.

## 0.15.0 — 2026-06-12

Init can no longer die halfway. An abandoned onboarding was the most common path to a half-configured project — nothing surfaced it.

- **init progress lives in `.devflow/INIT.md`** (same file-based-progress pattern ralph uses for its TODO): created as the first action, steps checked off as they complete, deleted only when live validation passes or is explicitly deferred with `# UNVERIFIED` markers.
- **New SessionStart hook `init-reminder.sh`**: a session opened in a project with a surviving INIT.md gets one deterministic context line — init is unfinished, resume with `/devflow:init`. Fail-open, never blocks, silent everywhere else.
- **Resume instead of STOP**: re-init protection now distinguishes "configured project" (manifest, no INIT.md → STOP as before) from "unfinished init" (manifest + INIT.md → continue from the first unchecked step, keep earlier answers).
- **Drift rule in init**: if the user diverts mid-init, help them, then steer back to the checklist; stopping for real is allowed but said out loud.
- doctor (layer 2) and config both report a surviving INIT.md as unfinished init; doctor layer 1 checks the new hook file.

## 0.14.0 — 2026-06-12

Stack-agnostic release: devflow serves any repo type, not just backends — and now says so everywhere.

- **init detects the project type first** (backend / frontend / mobile / library-CLI / infra-as-code / monorepo mix) and explores, interviews, and validates per type: a frontend gets dev-server/e2e questions, an IaC repo gets plan/validate, nobody gets irrelevant DB questions. `project.type` recorded in the manifest.
- **Tier-2 gaps generalized**: the constant is "agents can exercise the project end-to-end without a human" — headless auth, seed/fixture data, and a working change→run→observe loop, each in the type's own terms.
- **Empty optional manifest sections (auth, db, services, related_repos, tracker) = "not configured", never a failure** — encoded in the template, doctor, init validation, and test-flow.
- test-flow/api-tester: flows map to the project's own surface (API endpoints, UI routes via the project's e2e runner, CLI invocations, plan/validate) — curl is the tool for HTTP, not the definition of a flow.
- doctor: docker required only when the manifest references it.
- Sync descriptions caught up with the implementation (repo-agnostic since 0.4.0): examples now cover frontend, backend, mobile, shared contracts, infra-as-code; plugin.json no longer says "frontend sync"; template shows multiple counterpart examples.

## 0.13.2 — 2026-06-12

- README polish.

## 0.13.1 — 2026-06-12

- Docs rewritten in English and addressed to new users: README and docs/GUIDE.md (replaces GUIDE.ru.md). Author-internal framing ("handoff checklist") reworked into a user-facing "verify your installation"; legacy migration notes dropped.

## 0.13.0 — 2026-06-12

- **Marketplace packaging**: the repo is now its own plugin marketplace (`.claude-plugin/marketplace.json`) — install with `claude plugin marketplace add kebabovicz/devflow` + `claude plugin install devflow@devflow`. Closes the last Roadmap item and the reviewer's registry confusion: installed this way, devflow appears in the plugin registry like any other plugin.
- Two install modes documented: marketplace (users; updates via `claude plugin update`) vs symlink dev-mode (developing devflow itself; edits take effect immediately). One at a time — both together double-load everything.

## 0.12.0 — 2026-06-12

Hardening release driven by a cold adversarial review (fresh session, no author context — a transfer rehearsal).

- **guard.sh holes closed**: `docker-compose` (V1 hyphenated) now blocked alongside `docker compose`; `DEVFLOW_ALLOW=1` bypass anchored to a leading assignment (the string inside an echo/comment/argument no longer disarms the guard); quoted YAML values (`base_branch: "main"`) no longer silently disable checks; commit anchor tolerates leading whitespace, subshell `(` and `VAR=val` prefixes; `git -C <path> commit` checks the branch of the TARGET repo, not the session cwd.
- **Honest limits documented** in the script header and README: the guard is a floor against accidents, not a sandbox — arbitrary wrappers (`bash -c`) can smuggle commands past regexes.
- **doctor: hook REGISTRATION test** — the script working is not the hook firing. New check deliberately runs a harmless command containing the dangerous literal from the project root and expects its own tool call to be BLOCKED (the inverse of the 0.5.1 assembly trick); hooks are never reported healthy on script tests alone. Stop-gate self-test now covers the exit-2 path via a disposable sandbox.
- **ralph-stop-gate**: quoted `todo:` paths handled; empty-cwd behavior aligned with guard (fail-open); `footprint: local` inertness documented (TODO is git-excluded there — gate cannot fire; README states it).
- README/GUIDE: leaked project-specific issue-key examples really neutralized to `ABC-12` this time; GUIDE install URL concretized; review skill description clarified vs the built-in single-pass code-review.
- Review's headline finding ("hooks not registered at all") was a FALSE POSITIVE — confirmed live: the hook input `cwd` is the session's directory at call start, so testing with `cd <dir> && <cmd>` in one call evaluates the manifest of the OLD cwd. Both reviewer and verifier initially fell into the same trap; the registration test above exists so nobody falls into it silently again.
- Invocation-policy criterion restated correctly (0.11.1 wording was wrong): skills are slash-only not because they are "state-changing" but because they are heavy entry points needing an explicit goal (init, update, sync, ralph-*); task/issue/review also change state yet auto-invoke — their actions are gated inside the skill instead.

## 0.11.2 — 2026-06-11

- install.sh/GUIDE: Atlassian MCP endpoint updated to streamable HTTP (`/v1/mcp`) — the SSE endpoint is deprecated and shuts down 2026-06-30 (noticed live in a task run).
- task: the closing issue comment must carry the outcome (decision, evidence, commit ref) — a bare status transition is not a closed task; for research/decision tasks the comment IS the deliverable (a real run moved an issue to done without recording the investigated decision).

## 0.11.1 — 2026-06-11

- research: description strengthened with explicit trigger phrases (incl. Russian) so conversational asks ("давай проведём ресёрч") reliably auto-invoke the skill. Reminder of the invocation split: safe/read skills auto-invoke by intent; state-changing ones (init, update, sync, ralph-*) stay slash-only by design.

## 0.11.0 — 2026-06-11

- **sync-docs: parallel fan-out for full audits** — docs partitioned into 3–4 area buckets (manifest+CLAUDE.md isolated in their own bucket), one docs-sync agent per bucket spawned in parallel, reports aggregated into a single digest. Background execution offered so the session stays usable during the audit. Motivated by a real 25-minute serial full audit. Small scopes (≤3 docs) stay single-agent.

## 0.10.1 — 2026-06-11

- research: context7 is the first stop for library/framework/SDK questions; when its MCP is absent the skill offers the one-time `claude mcp add` setup and degrades gracefully to web search. install.sh mentions the optional setup.

## 0.10.0 — 2026-06-11

- **`/devflow:research`**: decision-grade web research with the methodology baked in — source hierarchy (primary > experience reports > community > SEO), mandatory contrarian pass ("X problems", "why we moved away"), triangulation (2+ independent sources per finding), dated facts, confidence grading (established/likely/disputed/unverified), explicit minority view and "what remains unknown". Heavy digs fan out to subagents; the session keeps conclusions, not raw search dumps. Works outside devflow projects too.

## 0.9.1 — 2026-06-11

- fix: ralph-stop-gate.sh shipped without the executable bit → "Permission denied" noise on every session stop (the chmod was lost to a tooling failure during 0.6.0). install.sh now chmods all hook scripts as a safety net; troubleshooting entry added.

## 0.9.0 — 2026-06-11

- **`/devflow:review`**: iterative review-fix-review loop until a pass comes back clean ("until 10/10"). The project's documented rules are the rubric and outrank generic taste. Built-in convergence rules: empty pass = success (never invent nits), fix-reversal = stop and surface, 3-pass cap with an honest residue assessment, every finding must cite its rule/defect class. Follows the session model — run in the strongest session for the polish workflow.
- init: projects without CLAUDE.md get pointed to the built-in `/init` — devflow consumes project rules, it doesn't author them.
- GUIDE: "where project rules live" section (CLAUDE.md / docs / manifest layering and how to extend each).

## 0.8.0 — 2026-06-11

- **`project.footprint: committed | local`** — privacy mode: `local` keeps devflow invisible in git (`.devflow/`, `.claude/`, CLAUDE.md section go to `.git/info/exclude` — never `.gitignore`, which is itself committed and would betray the setup). Ralph commits code only; TODO/manifest live on the machine. Asked during init interview, shown by `/devflow:config`. Trade-off stated openly: progress doesn't survive machines, teammates don't inherit the setup.
- **init re-run protection**: init on an onboarded project stops and offers `doctor` / `config` / `update` instead of overwriting earned knowledge; re-init only on explicit insistence.
- Uniform onboarding gate: every project-scoped skill (task, issue, sync, sync-docs, ralph-plan) now stops with a `/devflow:init` pointer when there is no manifest.

## 0.7.0 — 2026-06-11

- **`/devflow:config`**: read-only view of the project's devflow configuration — env, auth (recipe + verification status), tests, data policy, git conventions, tracker, related repos, ralph state, docs map; flags every `# TODO`/`UNVERIFIED` setting nobody confirmed yet.
- **init: settings review step** — before writing the manifest, the effective configuration is shown as a table (value + origin: derived/answered/default/TODO) and the user adjusts it there; defaults are proposals, not decisions.
- **init: answer validation** — enums (tracker system, relationship, on_done), reality checks (base branch and repo paths exist, patterns contain required placeholders, tracker url answers); unsupported asks are refused with the closest supported option named, never silently written.
- Scrubbed the last project-specific examples (issue keys, branch names) from skills, template and guide — examples are now neutral (`ABC-12`).

## 0.6.1 — 2026-06-11

- Model policy: api-tester and docs-sync pinned to `model: sonnet` (mechanical work — saves the session model's rate limits); ralph-build's implementation subagent explicitly inherits the session model (writes production code — never downgrade).

## 0.6.0 — 2026-06-11

Patterns adopted from the wider agentic-engineering ecosystem (GSD's fresh-context execution, Willison's red/green TDD), after comparing devflow against BMAD/GSD/SpecKit.

- **ralph-build: fresh context per iteration** — implementation + verification are delegated to a subagent with a clean context window; the orchestrating session holds only the loop's state. Fixes the quality decay of long `/loop` runs in a single accumulating context (GSD's core insight). Trivial tasks may still be done inline.
- ralph-build: the subagent's report is a claim — the orchestrator re-verifies (diff against spec, re-run "done when") before committing.
- ralph-plan: task sizing formalized — 2–3 concrete steps, ~half a fresh context window; every AC must map to a mechanically checkable pass/fail (executable test where a suite exists).
- ralph-build: red/green when tests are the AC — failing test seen red before implementing.
- **Stop hook `ralph-stop-gate.sh`**: deterministic commit gate — stopping with uncommitted ralph-TODO changes is blocked (once; fail-open; loop-protected via `stop_hook_active`). Yesterday's "tasks checked off but never committed" failure is now mechanically impossible, not just textually discouraged.
- doctor: layer 1 now self-tests the stop-gate alongside guard.sh.

## 0.5.2 — 2026-06-11

- manifest/init: `tracker.labels` is the team's area routing (e.g. BACKEND/FRONTEND/DEVOPS), asked during init interview — was a hardcoded `[devflow]` default that polluted real boards.
- ralph-build: commit is now a hard iteration gate — TODO checkmark and code go in ONE commit (was: commit, then mark done — the trailing TODO edit left the tree dirty and later iterations stopped committing entirely; found by the first real autonomous run, tasks 5–9 of 9 were left uncommitted with tests green).
- ralph-build: clean-tree invariant at iteration start — leftover changes from a dead iteration are committed before new work begins.
- ralph-plan/build: TODO is one flat checklist, tasks checked off in place — separate Pending/Completed sections drifted apart during the run.

## 0.5.1 — 2026-06-11

- doctor: guard self-test assembles the dangerous string at runtime (`printf … %s` prune) — the literal string in the test command triggered the session's own guard hook, making the self-test unrunnable inside guarded projects. Found by doctor's first run on itself.

## 0.5.0 — 2026-06-11

- **`/devflow:doctor`**: read-only diagnostics in three layers — installation (deps, guard self-test), project (manifest health, TODO/UNVERIFIED markers, committed permissions), and live (`doctor full`: env health, auth recipe, test run, tracker reachability). Every non-green check comes with a fix hint; verdict HEALTHY / DEGRADED / BROKEN.

## 0.4.0 — 2026-06-11

- **`/devflow:sync <repo>`** (ex-`sync-front`, breaking): generalized to any related repository. Manifest `frontend:` section replaced by `related_repos:` (name → path/branch/relationship: consumer|provider|sibling). The same skill now serves backend and frontend developers symmetrically. Sync state moved to `.devflow/sync/<name>.json`. Migrate manifests with `/devflow:update`.

## 0.3.0 — 2026-06-11

- **Guardrails (hooks)**: deterministic PreToolUse protection — destructive volume commands (`down -v`, `volume rm/prune`) and commits on the base branch are blocked in devflow projects. Fail-open, scoped to projects with a manifest, `DEVFLOW_ALLOW=1` escape hatch (explicit user request only).
- **install.sh**: one-command setup with dependency checks.
- Guide: parallel-work levels (single session → background worktree agent → Claude Squad), "when NOT to use devflow" section, troubleshooting additions (protoc/arm64, initdb on existing volume, busy 5432).
- Team permissions guidance: project allowlist belongs in committed `.claude/settings.json`, not gitignored `settings.local.json`.

## 0.2.0 — 2026-06-10

- **`/devflow:task`** (ex-`work`): full task pipeline — board question, branch from fresh base (`git` manifest section), live AC verification, built-in code-review step, knowledge sync, user-gated commit/push/status transitions.
- **`/devflow:issue`**: file tracker issues (Jira via MCP, REST fallback) from findings, draft + approval flow.
- **`/devflow:update`**: additive manifest migration after plugin updates.
- Manifest: `git` (base branch, branch/commit patterns, on_done), `tracker` (+wip/done statuses), `db` (persistent-data policy, snapshot/restore) sections.
- Data policy: local volumes are persistent test state; agents never destroy them.
- `init`: interview step for non-derivable preferences; mandatory live validation before reporting success.
- docs/GUIDE.ru.md — full Russian guide.

## 0.1.0 — 2026-06-10

- Initial skeleton: manifest template, skills (init, test-flow, ralph-plan, ralph-build, sync-front, sync-docs), agents (api-tester, docs-sync).
