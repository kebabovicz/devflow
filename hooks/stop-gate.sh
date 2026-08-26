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
#     progress in an effort belonging to the branch checked out here AND this
#     working tree is dirty. Maps resolve from the main working tree, so a
#     session inside a git worktree sees the same map as the main checkout.
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

# Maps live in the MAIN working tree: a git worktree checks out tracked files
# only, and the map is deliberately excluded from git. Resolving the map root
# from the common git dir gives every worktree of a repo the same map.
common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null) || exit 0
[ -z "$common" ] && exit 0
case "$common" in /*) ;; *) common="$cwd/$common" ;; esac
maps_root=$(cd "$(dirname "$common")" 2>/dev/null && pwd) || maps_root=""
[ -z "$maps_root" ] && maps_root="$cwd"
[ -d "$maps_root/$map_dir" ] || exit 0

# Which efforts belong to THIS working tree: the ones whose map.md names the
# branch checked out here. Without that filter a repo with several efforts —
# or several worktrees — cross-contaminates: a ticket in progress from effort A
# plus uncommitted files from effort B is not an unfinished iteration, it is
# two parallel tasks, and blocking the wrong session teaches people to ignore
# the gate.
branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=""
if [ -z "$branch" ]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch=""
fi
efforts=""
if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  for mapfile in "$maps_root/$map_dir"/*/map.md; do
    [ -f "$mapfile" ] || continue
    grep -qF -- "$branch" "$mapfile" 2>/dev/null \
      && efforts="$efforts$(dirname "$mapfile")
"
  done
fi
# No effort claims this branch (a map may record none) => consider all of them.
# Losing the gate entirely is worse than the occasional wrong pointer.
if [ -z "$efforts" ]; then
  for d in "$maps_root/$map_dir"/*/; do
    [ -d "$d" ] && efforts="$efforts${d%/}
"
  done
fi

ticket=""
while IFS= read -r effort_dir; do
  [ -n "$effort_dir" ] || continue
  [ -d "$effort_dir/tickets" ] || continue
  ticket=$(grep -rliE '^[[:space:]]*Status:[[:space:]]*in progress' \
    "$effort_dir/tickets"/*.md 2>/dev/null | head -1)
  [ -n "$ticket" ] && break
done <<EOF
$efforts
EOF
[ -z "$ticket" ] && exit 0

dirty=$(git -C "$cwd" status --porcelain 2>/dev/null) || exit 0
[ -z "$dirty" ] && exit 0

echo "devflow stop-gate: $(basename "$ticket") is in progress and the working tree is dirty — an iteration implemented work without committing it. Two legitimate exits: the work is finished and waiting for the user's own review → set Status: awaiting review in the ticket (never commit on your own initiative); or this is an unattended iteration → commit the ticket's files with a message referencing it, tick the checklist, set Status: done. A green test with a dirty tree and no one reviewing is a failed iteration." >&2
exit 2
