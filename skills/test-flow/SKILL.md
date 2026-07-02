---
description: Test a described user/business flow against the live local project — spins up the environment, authenticates when needed, executes the scenario step by step, reports expected vs actual. Use when asked to test a flow, verify an API or UI scenario, or check the project behaves as designed.
---

# Test flow: $ARGUMENTS

Verify the described flow against the real running services. Read `.devflow/project.yml` first — if it does not exist, stop and tell the user to run `/devflow:init`.

## Protocol

1. **Understand the flow**: map "$ARGUMENTS" to concrete steps in the project's own terms — API endpoints, UI routes/actions, CLI invocations, plan/validate runs, whatever the stack exposes. Sources of truth, in order: manifest `services` + their API schemas, the code, docs mapped in `docs.map`. State your expected scenario (steps, expected outcomes, expected side effects) BEFORE executing.
2. **Spin up**: determine the minimal environment for the flow, start via `env.up`, wait for `env.health`.
3. **Authenticate** if the flow touches a protected surface: `auth.recipe` for service-level access, `auth.user_recipe` when the flow acts as a specific user. Empty recipe with a `# none` marker → the surface is public by confirmed configuration: skip auth confidently. Empty recipe WITHOUT the marker → auth was never established: skip, but if a step then answers 401/403, that's a manifest gap, not a scenario error — report it and offer to derive the recipe WITH the user (never invent a bypass). Same rule when the flow needs a user token but `user_recipe` is empty.
4. **Check fixture preconditions**: a flow that needs data in a specific state (an order in Draft, a user with role X) checks that data exists BEFORE executing. Missing fixture → present options (seed it, set it up via API, targeted data edit with user approval) — pick one with the user, don't improvise.
5. **Execute** step by step using the surface's natural tool: curl for HTTP, the project's e2e runner (playwright/cypress) for UI flows when one exists, the CLI itself for CLIs, plan/validate for IaC. After each step verify: outcome, response/output shape, and side effects (data state, emitted events, generated files) where checkable.
6. **Report** as a table: step → expected → actual → ✅/❌. State each step's verification depth — response shape / status code only / side effects checked: a ✅ that only saw a status code must say so, it is a weaker claim. For failures include the failing request (method, path, body) and response verbatim. If mapping "$ARGUMENTS" to the scenario involved interpretation (ambiguous flow name, several candidate endpoints), name the choice you made — the user verifies the scenario before trusting its verdict.

## Rules

- Delegate execution to the `api-tester` agent when the scenario is HTTP-based and has more than ~3 steps — keep the main context clean. Non-HTTP scenarios (UI runner, CLI, IaC) run inline or in a general-purpose subagent.
- **Precondition budget applies on every path** (delegated or inline): environment, auth, and fixtures get ~10 tool calls of honest effort each — then stop and report the gap as a finding (what's missing, what manifest field or seed would fix it). Reverse-engineering a precondition is a manifest gap, not a challenge.
- Never "fix" the test to match broken behavior. A mismatch between docs and behavior is a finding, not an error in your scenario — report it.
- Tear down only what you started, and only if the user isn't using the environment interactively.
- **Local data is persistent test state**: never `down -v` or otherwise destroy databases/volumes unless the user explicitly asks. Before risky data-mutating scenarios, offer a snapshot if the manifest defines `db.snapshot`.
