---
description: Diagnosis discipline for a bug or a performance regression — no hypotheses until one command already goes red on this bug, then reproduce, minimise, hypothesise, instrument, fix with a regression test, clean up. Use when something is broken, throwing, failing, or slow, and the cause is not obvious.
---

# Diagnose: $ARGUMENTS

**Read `${CLAUDE_SKILL_DIR}/../OUTPUT-STYLE.md` before your first message and follow it** — it binds every message this skill prints and every file it writes for a person to read.

Read `.devflow/project.yml` when it exists: `test.run` and `test.integration`, `env.up` and `env.health`, `services` with their schemas, `auth.recipe`, `db.snapshot`. Those are the parts the feedback loop gets built from. No manifest → the skill still works, but say once that the project's own commands could not be loaded and you are deriving them.

**Never destroy local data to reproduce something.** No `down -v`, no drop, no truncate without the user asking for it; before a scenario that mutates data, offer `db.snapshot` if the manifest defines one.

**Redact.** This skill shows commands and their output. No token values, passwords, or connection strings — not even partial; write `<REDACTED>` and build loops against environment variables so the credential stays in the environment. If the redacted output is genuinely not enough to diagnose, say so and ask.

## Phase 1 — one command that goes red. This is the whole skill.

Everything after this is mechanical. With a command that fails on *this* bug and passes once it is fixed, the cause gets found; without one, reading code produces theories, and a theory that cannot be tested is where debugging sessions go to die.

**If you catch yourself reading code to build a theory before that command exists — stop.** Jumping to a hypothesis is the exact failure this skill prevents.

Ways to build it, roughly in this order. The project's own tools come first — a loop built out of what the project already runs is one the user can re-run tomorrow:

1. **A failing test** at whatever seam reaches the bug — `test.run` for the fast suite, `test.integration` when the path crosses services.
2. **An HTTP call** against the running environment: `env.up`, wait for `env.health`, authenticate per `auth.recipe`, then curl the endpoint from `services`. More than about three steps → hand it to the `api-tester` agent, the same way `/devflow:test-flow` does.
3. **A CLI invocation** with a fixture input, diffing output against a known-good one.
4. **A headless browser script** for a UI symptom, asserting on the DOM, the console, or the network — the project's own e2e runner if it has one.
5. **A replayed trace**: save the real request, payload, or event log, then push it through the code path in isolation.
6. **A throwaway harness** — the smallest slice of the system that reaches the bug in one function call, dependencies mocked.
7. **A property or fuzz loop** when the symptom is "sometimes wrong": a thousand inputs, looking for the failure mode.
8. **A bisection harness** when the bug appeared between two known states — automate "set state, check, repeat" until `git bisect run` can drive it.
9. **A differential run**: the same input through two versions or two configurations, outputs diffed.
10. **A human-in-the-loop script** — the last resort, when a person must click or authenticate physically. See below.

### The loop is done when it is tight

Name **one command** you have already run at least once, and show its invocation and output, redacted. It must be:

- **red-capable** — it drives the real code path and asserts the symptom *the user described*, not "did not crash". A loop that goes green on a broken system is worse than no loop.
- **deterministic** — the same verdict every run.
- **fast** — seconds. A thirty-second flaky loop is barely a loop; a two-second deterministic one is what makes the rest of this cheap.
- **agent-runnable** — you can run it unattended.

Then tighten it: cut setup, narrow the scope, pin the clock, seed the random source, freeze the network.

**Unstable bugs**: the goal is not a clean reproduction but a higher rate. Loop the trigger a hundred times, run them in parallel, add load, narrow the timing window, inject sleeps. Fifty percent is debuggable, one percent is not — keep raising it before going further.

**When you truly cannot build one**, stop and say so plainly: what you tried, and what would unblock it — access to the environment where it reproduces, a redacted artifact (HAR file, log dump, recording with timestamps), or permission to add temporary instrumentation where it happens. Do not proceed to hypotheses without a loop.

### The human-in-the-loop script

Some bugs need a person: a real second factor, a physical device, a UI with no runner, an environment only their machine reaches. Without structure that turns into a conversation — steps get skipped, observations arrive as prose, and the run after the fix is a different run, so there is nothing to compare.

Copy `${CLAUDE_SKILL_DIR}/hitl-loop.template.sh`, fill in the steps, and run it. `step` shows an instruction and waits; `capture` asks a question and stores the answer; at the end everything captured prints as `KEY=value` for you to read as data.

- **Only human steps go in it.** Whatever you can do yourself — start the environment, wait for health, make the request — happens before the script runs. Nobody should sit in their terminal watching machine steps.
- **No credentials in the script.** Signing in is a `step` for the person, never a captured value.
- **The working copy lives outside the project repository** — a temp directory, so a script full of one bug's steps cannot end up in a commit. With a map open on this work, offer to keep it in the effort's directory instead; that one is already outside git.

## Phase 2 — reproduce, then minimise

Run the loop, watch it go red, and confirm three things: the failure is the one **the user** described and not a neighbour, it repeats across runs (or at the raised rate), and you have captured the exact symptom to check the fix against later.

Then shrink it. Cut inputs, callers, configuration, data, and steps **one at a time**, re-running after each cut. Done when every remaining element is load-bearing — removing any one of them turns the loop green. The minimal case is what makes the next phase cheap, and it is the regression test later.

## Phase 3 — three to five hypotheses, before testing any

Generating one hypothesis anchors you to it. Generate three to five, rank them, and make each **falsifiable** — state the prediction: "if X is the cause, then changing Y removes the bug; changing Z makes it worse." A hypothesis with no prediction is a vibe; sharpen it or drop it.

**Show the ranked list to the user before testing anything.** They often re-rank it in one sentence — "we deployed a change to that yesterday" — or say which ones they already ruled out. Do not block on the answer: proceed with your ranking if they are away.

## Phase 4 — instrument, one variable at a time

Every probe maps to a specific prediction from the previous phase. A debugger or REPL beats logs where the environment allows it — one breakpoint says more than ten print statements. Where logs are the tool, put them at the boundaries that separate hypotheses, never "log everything and grep".

**Tag every debug log with a unique prefix**, `[DEBUG-a4f2]`. Cleanup then costs one grep, and untagged leftovers are what survive into production.

**Performance regressions take the other branch**: logs mislead. Establish a baseline measurement first — a timing harness, a profiler, a query plan — then bisect against it. Measure, then fix.

## Phase 5 — regression test first, then the fix

Write the regression test **before** the fix, at a seam where it exercises the real pattern as it occurs at the call site. Then: watch it fail, apply the fix, watch it pass, and re-run the Phase 1 loop against the original un-minimised scenario.

**If there is no correct seam, that is itself a finding** — a shallow test that cannot reproduce the chain gives false confidence, and the architecture is what is preventing the bug from being locked down. Say so, fix the bug anyway, and offer the finding as a tracker issue via `/devflow:issue`. What is not allowed is quietly writing the shallow test and calling it covered.

## Phase 6 — clean up, and put the cause where it will be read

Before declaring it done:

- the original reproduction no longer reproduces — the Phase 1 loop, re-run;
- the regression test passes, or its absence is written down with the reason;
- every `[DEBUG-...]` line is gone (grep the prefix), throwaway harnesses deleted, the human-in-the-loop script deleted unless the user asked to keep it — keep it when the bug is unstable or the post-fix check needs the same person again;
- **the cause goes into the commit message** — the hypothesis that turned out right, in one sentence. The next person to hit this area learns from it only if it is written there;
- **and wherever else it contradicts what is written**: a map's *How it works today*, a doc mapped in `docs.map`. Fix that text in the same change — a bug whose cause proves the documentation wrong has just told you the documentation is wrong.
