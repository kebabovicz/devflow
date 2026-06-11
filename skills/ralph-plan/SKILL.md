---
description: Ralph PLANNING mode — gap analysis between specs and code, producing a prioritized TODO that survives sessions. Use when starting a large task, breaking down a feature, or refreshing the task list.
disable-model-invocation: true
---

# Ralph: PLANNING

Goal/spec to plan for: $ARGUMENTS

Read `.devflow/project.yml` (paths below come from its `ralph` section); no manifest → stop: the project isn't onboarded, point to `/devflow:init`. Progress lives in **files and git history, not in your context** — anything not written down is lost.

## Protocol

1. **Load state**: read `ralph.todo` and existing specs in `ralph.specs_dir`. If "$ARGUMENTS" describes a new goal, write/update its spec file first: `<specs_dir>/<kebab-case-goal>.md` — what "done" means, constraints, affected areas (services, screens, modules — whatever the project's units are), verification strategy.
2. **Gap analysis**: compare each spec against the actual code. What exists, what's missing, what's drifted.
3. **Write the TODO** (`ralph.todo`): prioritized markdown checklist. Record the task branch name at the top (per `git.branch_pattern` from the manifest) — ralph-build iterations will work there. Each task:
   - small enough for one BUILDING iteration: 2–3 concrete steps, implementable inside roughly half of a fresh context window (one commit, limited blast radius). If a task needs more, split it;
   - has a verification line ("done when: `test.run` green on X / endpoint Y returns Z"). **Every acceptance criterion must map to a check that can pass or fail mechanically** — an executable test where the codebase has a test suite, a concrete command + expected output otherwise. "Looks right" is not a criterion;
   - references its spec file.
   Use ONE flat checklist — completed items stay in place, checked off with a result note. Do not create separate Pending/Completed sections: duplicated lists drift apart during the loop.
4. **Do not implement anything.** Planning only. Output a short summary of the top 3 tasks and any open questions the user must answer before building starts.
