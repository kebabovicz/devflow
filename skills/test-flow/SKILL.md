---
description: Test a described user/business flow against the live local project — spins up the environment, authenticates when needed, executes the scenario step by step, reports expected vs actual. Use when asked to test a flow, verify an API or UI scenario, or check the project behaves as designed.
---

# Test flow: $ARGUMENTS

Verify the described flow against the real running services. Read `.devflow/project.yml` first — if it does not exist, stop and tell the user to run `/devflow:init`.

## Protocol

1. **Understand the flow**: map "$ARGUMENTS" to concrete steps in the project's own terms — API endpoints, UI routes/actions, CLI invocations, plan/validate runs, whatever the stack exposes. Sources of truth, in order: manifest `services` + their API schemas, the code, docs mapped in `docs.map`. State your expected scenario (steps, expected outcomes, expected side effects) BEFORE executing.
2. **Spin up**: determine the minimal environment for the flow, start via `env.up`, wait for `env.health`.
3. **Authenticate** per `auth.recipe` if the flow touches a protected surface (no auth section configured → skip; never invent a bypass).
4. **Execute** step by step using the surface's natural tool: curl for HTTP, the project's e2e runner (playwright/cypress) for UI flows when one exists, the CLI itself for CLIs, plan/validate for IaC. After each step verify: outcome, response/output shape, and side effects (data state, emitted events, generated files) where checkable.
5. **Report** as a table: step → expected → actual → ✅/❌. For failures include the failing request (method, path, body) and response verbatim.

## Rules

- Delegate execution to the `api-tester` agent when the scenario is HTTP-based and has more than ~3 steps — keep the main context clean. Non-HTTP scenarios (UI runner, CLI, IaC) run inline or in a general-purpose subagent.
- Never "fix" the test to match broken behavior. A mismatch between docs and behavior is a finding, not an error in your scenario — report it.
- Tear down only what you started, and only if the user isn't using the environment interactively.
- **Local data is persistent test state**: never `down -v` or otherwise destroy databases/volumes unless the user explicitly asks. Before risky data-mutating scenarios, offer a snapshot if the manifest defines `db.snapshot`.
