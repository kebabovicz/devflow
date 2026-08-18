#!/bin/bash
# devflow stop-gate — deterministic enforcement of the build commit gate.
#
# An iteration that implements a ticket and stops without committing loses the
# work's only durable trace (the exact failure mode of the first autonomous
# run: tasks finished green and were left uncommitted). Text rules in the skill
# ask for the commit; this hook makes stopping without it impossible — once.
#
# The gate needs a signal that an iteration is actually in flight, or every
# interactive session would trip it. That signal is a map ticket marked
# `Status: in progress`: /devflow:build and /devflow:task set it when they pick
# a ticket up and clear it when the commit lands. Map files live outside git,
# so a dirty tree here means uncommitted CODE, never planning noise.
#
# Design rules (same as guard.sh):
#   * FAIL-OPEN: any parsing/tooling problem => exit 0 (allow stop).
#   * Scoped: only fires when cwd has .devflow/project.yml AND a ticket is in
#     progress AND the working tree is dirty.
#   * No loops: if stop_hook_active is set, a previous block already fired —
#     allow the stop rather than trapping the session.
#   * A legitimate mid-ticket stop costs the user one nudge, then goes through.
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0

active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && exit 0
manifest="$cwd/.devflow/project.yml"
[ -f "$manifest" ] || exit 0

# Map directory from the manifest's `maps:` section; default matches the template.
# Strip inline comments and surrounding quotes (quoted YAML is valid YAML).
map_dir=$(grep -E '^[[:space:]]*dir:' "$manifest" | head -1 \
  | sed -e 's/^[[:space:]]*dir:[[:space:]]*//' \
        -e 's/[[:space:]]*#.*$//' \
        -e 's/^"\(.*\)"$/\1/' \
        -e "s/^'\(.*\)'\$/\1/" \
        -e 's/[[:space:]]*$//')
[ -z "$map_dir" ] && map_dir=".devflow/maps"
[ -d "$cwd/$map_dir" ] || exit 0

ticket=$(grep -rliE '^[[:space:]]*Status:[[:space:]]*in progress' \
  "$cwd/$map_dir"/*/tickets/ 2>/dev/null | head -1)
[ -z "$ticket" ] && exit 0

dirty=$(git -C "$cwd" status --porcelain 2>/dev/null) || exit 0
[ -z "$dirty" ] && exit 0

echo "devflow stop-gate: $(basename "$ticket") is in progress and the working tree is dirty — an iteration implemented work without committing it. Finish the iteration first: commit the ticket's files (message referencing the ticket), tick its acceptance checklist, set Status: done, then stop. A green test with a dirty tree is a failed iteration." >&2
exit 2
