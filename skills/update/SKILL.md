---
description: Migrate the project's devflow manifest to the current plugin template — adds newly introduced sections and keys, never overwrites existing values. Use after updating the devflow plugin.
disable-model-invocation: true
---

# devflow update

Compare `.devflow/project.yml` against the current template at `${CLAUDE_PLUGIN_ROOT}/templates/project.yml` and migrate the manifest forward.

## Protocol

1. **Diff schemas**: find sections/keys present in the template but missing from the project manifest.
2. **Add missing pieces** in the template's position: fill values you can derive cheaply (from the manifest itself, the conversation, or obvious repo files) — otherwise insert the template default with a `# TODO` comment. Do NOT re-explore the whole repo; this is a migration, not a re-init.
3. **Never overwrite, reorder, or "clean up" existing values and comments** — they carry verified operational knowledge (e.g. `# VERIFIED` recipes, port-conflict notes). Additions only.
4. **Orphans**: keys in the manifest that the template no longer has → leave them, flag as possibly obsolete in the report.
5. **Report**: added sections, TODOs requiring the user, flagged orphans.
