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
if [ -d "$cwd/$map_dir" ]; then
  for mapfile in "$cwd/$map_dir"/*/map.md; do
    [ -f "$mapfile" ] || continue
    effort_dir=$(dirname "$mapfile")
    effort=$(basename "$effort_dir")

    # Decision tickets: unresolved ones, and which of them are takeable now
    # (unblocked = every id in "Blocked by" already resolved, and unclaimed).
    resolved=" " unresolved=0 ready=0
    if [ -d "$effort_dir/issues" ]; then
      for f in "$effort_dir/issues"/*.md; do
        [ -f "$f" ] || continue
        grep -qiE '^[[:space:]]*Status:[[:space:]]*resolved' "$f" 2>/dev/null \
          && resolved="$resolved$(basename "$f" | sed 's/[^0-9].*$//') "
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
          case "$resolved" in *" $b "*) ;; *) blocked=1 ;; esac
        done
        [ "$blocked" -eq 0 ] && ready=$((ready+1))
      done
    fi

    if [ "$unresolved" -gt 0 ]; then
      echo "devflow map '$effort': $unresolved open decision(s), $ready ready to take — /devflow:map continues it; decisions live in $map_dir/$effort/."
      continue
    fi

    # Decisions all settled: either the map still owes its three outputs,
    # or what is left is implementation tickets.
    if [ ! -d "$effort_dir/tickets" ]; then
      # Only nag once decisions actually exist — an empty scaffold is not an effort.
      [ -d "$effort_dir/issues" ] && [ -n "$(ls -A "$effort_dir/issues" 2>/dev/null)" ] \
        && echo "devflow map '$effort': every decision resolved, no tickets cut yet — /devflow:map closes it into spec, design, and tickets."
    else
      left=$(grep -LiE '^[[:space:]]*Status:[[:space:]]*done' "$effort_dir/tickets"/*.md 2>/dev/null | wc -l | tr -d ' ')
      [ "${left:-0}" -gt 0 ] && echo "devflow map '$effort': decisions settled, ${left} implementation ticket(s) left — /devflow:task $map_dir/$effort/tickets/<ticket>.md."
    fi
  done
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
