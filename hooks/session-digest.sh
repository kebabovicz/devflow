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
exit 0
