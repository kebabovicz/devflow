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

# Ralph loop state: started large work must not be invisible at session start.
todo=$(yml_value todo)
[ -z "$todo" ] && todo=".devflow/TODO.md"
if [ -f "$cwd/$todo" ]; then
  unchecked=$(grep -cE '^[[:space:]]*- \[ \]' "$cwd/$todo" 2>/dev/null) || unchecked=0
  blocked=$(awk '/^## Blocked/{b=1;next} /^## /{b=0} b && /^[[:space:]]*-/{n++} END{print n+0}' "$cwd/$todo" 2>/dev/null) || blocked=0
  if [ "${unchecked:-0}" -gt 0 ] || [ "${blocked:-0}" -gt 0 ]; then
    line="devflow ralph: $unchecked unchecked task(s)"
    [ "${blocked:-0}" -gt 0 ] && line="$line, $blocked blocked"
    echo "$line in $todo — /devflow:ralph-build continues the loop; blocked items need the user."
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
