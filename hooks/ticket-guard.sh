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
#     environment disarms this hook. Verified to work for a session started by
#     hand; `claude --bg` does not pass the caller's environment to the session,
#     so a background session cannot be disarmed that way and does not need to
#     be — it reaches work through `session start`, which takes the ticket.
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
# NotebookEdit names its target `notebook_path`, every other edit tool uses
# `file_path`. Reading both means the matcher and the parsing agree; reading one
# would let notebooks through a gate that claims to cover them.
file=$(printf '%s' "$input" \
       | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

manifest="$cwd/.devflow/project.yml"
[ -f "$manifest" ] || exit 0

case "$file" in /*) ;; *) file="$cwd/$file" ;; esac

maps_root=$(df_maps_root "$cwd")
map_dir=$(df_maps_dir "$manifest")
maps_path="$maps_root/$map_dir"
[ -d "$maps_path" ] || exit 0

# ── the state headers belong to the engine ──────────────────────────────────
#
# A ticket's `Status:`, `Contract:`, `Reported:` and `Accepted:` lines are what
# the pult reads and what every other gate is armed by. Typed by hand they are
# just markdown: a session can write `Status: done` on work nobody accepted and
# the board fills with green that means nothing. The commands are how they move.
#
# Only the header lines. Everything else in a ticket — what it delivers, the
# design notes, a question's body — is prose a person and a session both edit
# freely, and guarding that would make the map unusable.
#
# The payload is what the tool is about to write: `new_string` for an edit,
# `content` for a whole-file write. A header that is not changing is not
# blocked, so re-writing a ticket with its current status intact goes through,
# and so does creating one that did not exist.
if printf '%s' "$file" | grep -qE '/tickets/[^/]+\.md$' && [ -f "$file" ]; then
  payload=$(printf '%s' "$input" \
            | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)
  if [ -n "$payload" ]; then
    for key in Status Contract Reported Accepted; do
      want=$(printf '%s\n' "$payload" | sed -nE "s/^$key:[[:space:]]*//p" | head -1)
      [ -n "$want" ] || continue
      have=$(df_header "$file" "$key" 2>/dev/null) || have=""
      [ "$want" = "$have" ] && continue
      echo "devflow ticket guard: '$key' on $(basename "$file" .md) is engine state, not text to type. It moves with a command — take, report, accept, contract draft/approve, question add/answer — so that what the board shows is what actually happened. Editing the rest of the ticket is untouched. Deliberate exception: DEVFLOW_ALLOW=1 in the session's environment." >&2
      exit 2
    done
  fi
fi

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

# Never on the base branch. Under devflow's own rules work does not happen
# there — guard.sh already blocks committing on it — so an edit on the base
# branch is a hotfix, a rebase fixup or a look around, none of which a ticket
# gate should stand in front of. It is also where the loose match below would
# do the most damage: maps name the base branch constantly ("branched off
# develop"), and every one of those mentions would arm the gate.
base=$(df_yml_section_value "$manifest" git base_branch 2>/dev/null) || base=""
[ -n "$base" ] && [ "$branch" = "$base" ] && exit 0

# Efforts whose map names this branch, in backticks — the form a map writes a
# branch in ("Ветка работы — `feature/AIZHOL-493`"). A bare substring is not
# enough: a map that happens to contain the English word "main" would arm the
# gate for the main branch, and a gate that refuses on a coincidence is a gate
# people switch off. A map that names its branch without backticks leaves the
# gate silent, which is the fail-open direction every hook here takes.
#
# Residual, and deliberate: a map naming ANOTHER branch as the one it was cut
# from arms the gate for that branch too. Narrowing further would mean parsing
# the prose around the name. The cost is bounded — the gate only speaks when
# that map also has live tickets and none of them is in progress.
#
# Unlike the stop gate, a branch no map claims does NOT widen to every effort:
# this hook refuses an action rather than nudging at the end of one.
branch_re=$(printf '%s' "$branch" | sed -e 's/[][\.^$*+?(){}|\\]/\\&/g')
efforts=""
for mapfile in "$maps_path"/*/map.md; do
  [ -f "$mapfile" ] || continue
  grep -qE -- "\`$branch_re\`" "$mapfile" 2>/dev/null \
    && efforts="$efforts$(dirname "$mapfile")
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

# The CLI ships with the plugin and is not on PATH, so the message names the
# path that actually works from here rather than a command that may not resolve.
# Resolved rather than printed with a `..` in the middle: this path is meant to
# be copied and run.
CLI=$(cd "$SELF_DIR/.." 2>/dev/null && pwd)/bin/devflow

# The bypass reaches a session started by hand — `DEVFLOW_ALLOW=1 claude` — and
# measurably does NOT reach one started with `claude --bg`, which does not pass
# the caller's environment through. That costs a dispatched session nothing: it
# got here through `session start`, which takes the ticket first, so this gate
# never speaks to it.
echo "devflow ticket guard: no ticket is in progress for $branch, so this change belongs to nothing. Take one first — '$CLI ticket take <id>', or '$CLI session start <id>' to work it in its own session. Ready here: ${live% }. If this edit genuinely belongs to no ticket, restart the session as 'DEVFLOW_ALLOW=1 claude' (a background session cannot be disarmed that way — it takes its ticket through 'session start')." >&2
exit 2
