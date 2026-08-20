#!/bin/bash
# devflow session digest — deterministic anti-drift context.
#
# Skills reload their rules only when invoked; between invocations nothing
# pins the project's conventions in a long session. This hook puts the
# load-bearing manifest facts (base branch, naming, data policy) into the
# context of EVERY session opened in a devflow project — the rules are
# present from token zero, not from the first skill call.
#
# Design rules (same as the other hooks):
#   * FAIL-OPEN: any parsing/tooling problem => exit 0 (stay silent).
#   * Scoped: only fires when the session cwd has .devflow/project.yml.
#   * Never blocks: SessionStart stdout is informational context, exit 0 always.
#   * Keys read here are grep-parsed (first match wins) — tests/lint.test.sh
#     enforces that they stay unique in the manifest template.
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && exit 0
manifest="$cwd/.devflow/project.yml"
[ -f "$manifest" ] || exit 0

yml_value() {
  grep -E "^[[:space:]]*$1:" "$manifest" | head -1 \
    | sed -e "s/^[[:space:]]*$1:[[:space:]]*//" \
          -e 's/[[:space:]]*#.*$//' \
          -e 's/^"\(.*\)"$/\1/' \
          -e "s/^'\(.*\)'\$/\1/" \
          -e 's/[[:space:]]*$//'
}

base=$(yml_value base_branch)
branch=$(yml_value branch_pattern)
commitp=$(yml_value commit_pattern)

echo "devflow project — conventions live in .devflow/project.yml (view: /devflow:config)."
if [ -n "$base" ]; then
  line="devflow git: base branch '$base' — history on it is hook-guarded (commit/push/merge blocked)"
  [ -n "$branch" ] && line="$line; task branches: $branch"
  [ -n "$commitp" ] && line="$line; commit format: $commitp"
  echo "$line."
fi
echo "devflow data: local volumes are persistent test state — never destroy them without an explicit user request (hook-guarded)."

# ── Conditional state lines — printed ONLY when something needs attention. ──
# A line that appears only when actionable gets read; a line that is always
# there gets skimmed. When the project is clean, the digest stays 3 lines.

# Decision maps: an effort planned but not carried through is the easiest thing
# to abandon silently — the map lives outside git, so nothing else reminds of it.
# `dir` is the sole key of the manifest's `maps:` section (lint keeps it unique).
map_dir=$(yml_value dir)
[ -z "$map_dir" ] && map_dir=".devflow/maps"

# Maps live in the MAIN working tree — a git worktree checks out tracked files
# only, and the map is excluded from git by design. Resolve the root from the
# common git dir so a session inside a worktree sees the same map as the main
# checkout instead of no map at all.
maps_root="$cwd"
common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null) || common=""
if [ -n "$common" ]; then
  case "$common" in /*) ;; *) common="$cwd/$common" ;; esac
  resolved=$(cd "$(dirname "$common")" 2>/dev/null && pwd) || resolved=""
  [ -n "$resolved" ] && maps_root="$resolved"
fi

# symbolic-ref first: it answers on an unborn branch too (a repo whose first
# commit has not landed), where rev-parse HEAD fails outright.
branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=""
if [ -z "$branch" ]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch=""
fi
[ "$branch" = "HEAD" ] && branch=""

if [ -d "$maps_root/$map_dir" ]; then
  mine="" others="" other_count=0
  for mapfile in "$maps_root/$map_dir"/*/map.md; do
    [ -f "$mapfile" ] || continue
    effort_dir=$(dirname "$mapfile")
    effort=$(basename "$effort_dir")

    # Decision tickets: unresolved ones, and which of them are takeable now
    # (unblocked = every id in "Blocked by" already resolved, and unclaimed).
    resolved_ids=" " unresolved=0 ready=0
    if [ -d "$effort_dir/issues" ]; then
      for f in "$effort_dir/issues"/*.md; do
        [ -f "$f" ] || continue
        grep -qiE '^[[:space:]]*Status:[[:space:]]*resolved' "$f" 2>/dev/null \
          && resolved_ids="$resolved_ids$(basename "$f" | sed 's/[^0-9].*$//') "
      done
      for f in "$effort_dir/issues"/*.md; do
        [ -f "$f" ] || continue
        grep -qiE '^[[:space:]]*Status:[[:space:]]*resolved' "$f" 2>/dev/null && continue
        unresolved=$((unresolved+1))
        grep -qiE '^[[:space:]]*Status:[[:space:]]*claimed' "$f" 2>/dev/null && continue
        blockers=$(grep -iE '^[[:space:]]*Blocked by:' "$f" 2>/dev/null | head -1 \
          | sed -e 's/^[^:]*:[[:space:]]*//' -e 's/[^0-9]\{1,\}/ /g')
        blocked=0
        for b in $blockers; do
          case "$resolved_ids" in *" $b "*) ;; *) blocked=1 ;; esac
        done
        [ "$blocked" -eq 0 ] && ready=$((ready+1))
      done
    fi

    line=""
    if [ "$unresolved" -gt 0 ]; then
      line="devflow map '$effort': $unresolved open decision(s), $ready ready to take — /devflow:map continues it; decisions live in $map_dir/$effort/."
    elif [ ! -d "$effort_dir/tickets" ]; then
      # Only nag once decisions actually exist — an empty scaffold is not an effort.
      [ -d "$effort_dir/issues" ] && [ -n "$(ls -A "$effort_dir/issues" 2>/dev/null)" ] \
        && line="devflow map '$effort': every decision resolved, no tickets cut yet — /devflow:map closes it into spec, design, and tickets."
    else
      left=$(grep -LiE '^[[:space:]]*Status:[[:space:]]*done' "$effort_dir/tickets"/*.md 2>/dev/null | wc -l | tr -d ' ')
      [ "${left:-0}" -gt 0 ] \
        && line="devflow map '$effort': decisions settled, ${left} implementation ticket(s) left — /devflow:task $map_dir/$effort/tickets/<ticket>.md."
    fi
    [ -z "$line" ] && continue

    # One effort belongs to this working tree — the one whose map names the
    # branch checked out here. The rest are other people's tasks (or your own,
    # in another worktree) and get one collapsed line: a digest that prints a
    # paragraph per open effort stops being read at around the third one.
    if [ -n "$branch" ] && grep -qF -- "$branch" "$mapfile" 2>/dev/null; then
      mine="$mine$line
"
    else
      other_count=$((other_count+1))
      others="$others$line
"
    fi
  done

  if [ -n "$mine" ]; then
    printf '%s' "$mine"
    [ "$other_count" -gt 0 ] \
      && echo "devflow maps: $other_count other open effort(s) in $map_dir/ — not on this branch."
  elif [ "$other_count" -eq 1 ]; then
    # Nothing claims this branch and there is exactly one open effort: an older
    # map that never recorded a branch, or work not branched yet. Show it.
    printf '%s' "$others"
  elif [ "$other_count" -gt 1 ]; then
    echo "devflow maps: $other_count open effort(s) in $map_dir/, none naming branch '${branch:-?}' — /devflow:map lists them."
  fi
fi

# Manifest hygiene: unconfirmed settings should nag quietly until settled.
unver=$(grep -cE '#[[:space:]]*UNVERIFIED' "$manifest" 2>/dev/null) || unver=0
todos=$(grep -cE '#[[:space:]]*TODO' "$manifest" 2>/dev/null) || todos=0
if [ "${unver:-0}" -gt 0 ] || [ "${todos:-0}" -gt 0 ]; then
  parts=""
  [ "${unver:-0}" -gt 0 ] && parts="$unver UNVERIFIED"
  if [ "${todos:-0}" -gt 0 ]; then
    [ -n "$parts" ] && parts="$parts, "
    parts="$parts$todos TODO"
  fi
  echo "devflow manifest: $parts marker(s) — /devflow:revalidate executes and re-marks unverified fields; TODO fields need values (edit the manifest or just ask)."
fi
exit 0
