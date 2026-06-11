#!/bin/bash
# devflow guardrails — deterministic protection for devflow-managed projects.
#
# Design rules:
#   * FAIL-OPEN: any parsing/tooling problem => exit 0 (allow). A broken guard
#     must never paralyze sessions.
#   * Scoped: only active when the SESSION cwd has a .devflow/project.yml.
#     NOTE: scoping uses the hook's cwd field (the session's working directory
#     at call start) — a `cd` inside the command itself does not move it.
#   * Escape hatch: a command STARTING with DEVFLOW_ALLOW=1 bypasses the guard.
#     Anchored to the start on purpose — the string appearing inside an echo,
#     a comment, or another argument does NOT disarm the guard.
#   * Honest limits: an arbitrary wrapper (bash -c '...', a script file) can
#     smuggle a blocked command past these regexes. The guard raises the floor
#     against accidents and model forgetfulness; it is not a sandbox.
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

# Explicit user-approved bypass — leading assignment only.
case "$cmd" in
  DEVFLOW_ALLOW=1) exit 0 ;;
  DEVFLOW_ALLOW=1[[:space:]]*) exit 0 ;;
esac

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && exit 0
manifest="$cwd/.devflow/project.yml"
[ -f "$manifest" ] || exit 0

# Read a scalar manifest value: strip inline comments, surrounding quotes, whitespace.
yml_value() {
  grep -E "^[[:space:]]*$1:" "$manifest" | head -1 \
    | sed -e "s/^[[:space:]]*$1:[[:space:]]*//" \
          -e 's/[[:space:]]*#.*$//' \
          -e 's/^"\(.*\)"$/\1/' \
          -e "s/^'\(.*\)'\$/\1/" \
          -e 's/[[:space:]]*$//'
}

# ── Guard 1: persistent data volumes are sacred ─────────────────────────────
# Covers `docker compose` (V2) and `docker-compose` (V1 hyphenated).
if printf '%s' "$cmd" | grep -qE 'docker([[:space:]]+compose|-compose)[^|;&]*[[:space:]]down([[:space:]][^|;&]*)?[[:space:]](-v|--volumes)|docker[[:space:]]+volume[[:space:]]+(rm|prune)'; then
  echo "devflow guard: destructive volume command blocked — local DB volumes are persistent test state (manifest db policy). If the user explicitly asked for this reset, re-run prefixed with DEVFLOW_ALLOW=1." >&2
  exit 2
fi

# ── Guard 2: no commits directly on the base branch ─────────────────────────
# Anchors tolerate leading whitespace, subshell '(' and VAR=val env prefixes.
if printf '%s' "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit'; then
  base=$(yml_value base_branch)
  # Honor `git -C <path>`: the commit lands in THAT repo, not the session cwd.
  target=$(printf '%s' "$cmd" | sed -n 's/.*git[[:space:]]\{1,\}-C[[:space:]]\{1,\}\([^[:space:]]\{1,\}\).*/\1/p' | head -1)
  if [ -n "$target" ]; then
    case "$target" in /*) ;; *) target="$cwd/$target" ;; esac
  else
    target="$cwd"
  fi
  cur=$(git -C "$target" branch --show-current 2>/dev/null)
  if [ -n "$base" ] && [ -n "$cur" ] && [ "$cur" = "$base" ]; then
    echo "devflow guard: committing directly on '$base' is blocked — create a task branch per the manifest git conventions (branch_pattern). If the user explicitly asked to commit on '$base', re-run prefixed with DEVFLOW_ALLOW=1." >&2
    exit 2
  fi
fi

exit 0
