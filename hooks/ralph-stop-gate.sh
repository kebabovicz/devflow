#!/bin/bash
# devflow ralph stop-gate — deterministic enforcement of the ralph commit gate.
#
# A dirty ralph TODO in the working tree means an iteration checked a task off
# but never committed (the exact failure mode of the first autonomous run:
# tasks 5-9 finished green and were left uncommitted). Text rules in the skill
# ask for the commit; this hook makes stopping without it impossible — once.
#
# Design rules (same as guard.sh):
#   * FAIL-OPEN: any parsing/tooling problem => exit 0 (allow stop).
#   * Scoped: only fires when cwd has .devflow/project.yml AND the ralph TODO
#     itself has uncommitted modifications. Interactive sessions rarely touch
#     the TODO, so false positives are a one-time nudge at worst.
#   * No loops: if stop_hook_active is set, a previous block already fired —
#     allow the stop rather than trapping the session.
#   * Known limit: in `footprint: local` mode the TODO is git-excluded and
#     never reads as dirty, so this gate is inert there — the commit gate is
#     enforced only by the skill text in that mode.
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0

active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && exit 0
manifest="$cwd/.devflow/project.yml"
[ -f "$manifest" ] || exit 0

# TODO path from the manifest's ralph section; default matches the template.
# Strip inline comments and surrounding quotes (quoted YAML is valid YAML).
todo=$(grep -E '^[[:space:]]*todo:' "$manifest" | head -1 \
  | sed -e 's/^[[:space:]]*todo:[[:space:]]*//' \
        -e 's/[[:space:]]*#.*$//' \
        -e 's/^"\(.*\)"$/\1/' \
        -e "s/^'\(.*\)'\$/\1/" \
        -e 's/[[:space:]]*$//')
[ -z "$todo" ] && todo=".devflow/TODO.md"
[ -f "$cwd/$todo" ] || exit 0

dirty=$(git -C "$cwd" status --porcelain -- "$todo" 2>/dev/null) || exit 0
[ -z "$dirty" ] && exit 0

echo "devflow ralph stop-gate: $todo has uncommitted changes — a ralph iteration checked off work without committing it. Finish the iteration first: commit the task's files together with the TODO checkmark (one atomic commit, message referencing the task), then stop. A green test with a dirty tree is a failed iteration." >&2
exit 2
