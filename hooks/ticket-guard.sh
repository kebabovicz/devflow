#!/bin/bash
# devflow ticket guard — a code change belongs to a ticket.
#
# The skills say to take a ticket before touching code. That is a rule a model
# follows until it forgets, and a forgotten claim is not a small slip: the
# ticket carries the contract, the claim keeps a second session out of the same
# tree, and work that belongs to no ticket cannot be reviewed against anything.
#
# Design rules (same as guard.sh and stop-gate.sh):
#   * FAIL-OPEN: any parsing or tooling problem => exit 0 (allow the edit).
#   * Scoped, and narrowly. It arms only where implementation work for the
#     branch checked out here is charted AND still live, and only for files
#     that are not part of the map itself. In a project with no map for this
#     branch, or whose tickets are all finished, it never speaks.
#   * Armed by the state of the work, never by which window started the
#     session. A gate that only applied to sessions the pult launched would
#     leave every ordinary terminal unchecked, and the guarantee belongs to the
#     work rather than to the window.
#   * Escape hatch: take a ticket — one command, and the honest way out. For
#     the case where that is wrong, DEVFLOW_ALLOW=1 in the session's
#     environment disarms this hook.
#   * Honest limits: a write done through Bash (`cat > file`, `sed -i`) is not
#     an Edit tool call and is not seen here. Nor is an edit in a directory the
#     session did not start in. The gate raises the floor against forgetting to
#     take a ticket; it is not a sandbox.
set -u

command -v jq >/dev/null 2>&1 || exit 0

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 0
# shellcheck source=../lib/devflow-lib.sh
. "$SELF_DIR/../lib/devflow-lib.sh" 2>/dev/null || exit 0

# Explicit, deliberate bypass.
[ "${DEVFLOW_ALLOW:-}" = "1" ] && exit 0

input=$(cat) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || exit 0
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

manifest="$cwd/.devflow/project.yml"
[ -f "$manifest" ] || exit 0

case "$file" in /*) ;; *) file="$cwd/$file" ;; esac

maps_root=$(df_maps_root "$cwd")
map_dir=$(df_maps_dir "$manifest")
maps_path="$maps_root/$map_dir"
[ -d "$maps_path" ] || exit 0

# The map is how a ticket gets taken, a contract gets drafted and a question
# gets answered. Guarding those edits would make the gate impossible to satisfy.
case "$file" in
  "$maps_path"/*) exit 0 ;;
  "$cwd"/.devflow/*) exit 0 ;;
  "$maps_root"/.devflow/*) exit 0 ;;
esac

# Only files of this project. An edit somewhere else is not this project's rule
# to enforce.
case "$file" in
  "$cwd"/*) ;;
  "$maps_root"/*) ;;
  *) exit 0 ;;
esac

branch=$(df_branch "$cwd")
[ -n "$branch" ] || exit 0

# Efforts whose map names this branch. Unlike the stop gate, a branch no map
# claims does NOT widen to every effort: this hook refuses an action rather
# than nudging at the end of one, and a refusal earned by the wrong map is how
# a gate teaches people to switch it off.
efforts=""
for mapfile in "$maps_path"/*/map.md; do
  [ -f "$mapfile" ] || continue
  grep -qF -- "$branch" "$mapfile" 2>/dev/null && efforts="$efforts$(dirname "$mapfile")
"
done
[ -n "$efforts" ] || exit 0

# Live tickets say implementation is underway here. A map whose tickets are all
# done or cancelled is history, and history does not gate anything.
live="" ; in_progress=""
while IFS= read -r effort_dir; do
  [ -n "$effort_dir" ] || continue
  [ -d "$effort_dir/tickets" ] || continue
  for t in "$effort_dir/tickets"/*.md; do
    [ -f "$t" ] || continue
    case "$(df_status_norm "$(df_header "$t" Status)")" in
      "in progress") in_progress="$in_progress$(basename "$t" .md) " ; live="$live$(basename "$t" .md) " ;;
      open|blocked)  live="$live$(basename "$t" .md) " ;;
    esac
  done
done <<EOF
$efforts
EOF

[ -n "$live" ] || exit 0
[ -n "$in_progress" ] && exit 0

echo "devflow ticket guard: no ticket is in progress for $branch, so this change belongs to nothing. Take one first — 'devflow ticket take <id>', or 'devflow session start <id>' to work it in its own session. Ready here: ${live% }. If this edit genuinely belongs to no ticket, start the session with DEVFLOW_ALLOW=1 in its environment." >&2
exit 2
