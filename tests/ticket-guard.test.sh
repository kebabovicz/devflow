#!/bin/bash
# Regression suite for hooks/ticket-guard.sh — the gate that keeps a code change
# attached to a ticket. Run via tests/run.sh or directly.
# Requires: bash, jq, git.
#
# The cases that matter are the ones where it must STAY SILENT. A gate that
# fires on ordinary work gets switched off, and then it guards nothing.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/ticket-guard.sh"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

REPO="$SANDBOX/repo"
MAPS="$REPO/.devflow/maps"
E="$MAPS/alpha"

setup() { # $1=branch named in map.md
  rm -rf "$REPO"
  mkdir -p "$E/tickets"
  git -C "$REPO" init -q -b work 2>/dev/null
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
  printf 'maps:\n  dir: .devflow/maps\n' > "$REPO/.devflow/project.yml"
  printf '# alpha\n\nВетка работы — `%s`.\n' "${1:-work}" > "$E/map.md"
  # (the backtick form is what a map writes, and what the gate reads)
  mkdir -p "$REPO/src"
  printf 'code\n' > "$REPO/src/app.ts"
}

switch() { # $1=branch to check out in the sandbox
  git -C "$REPO" checkout -q -B "$1" 2>/dev/null
}

mk() { # $1=name $2=status
  printf '# %s — %s\n\nBlocked by: none\nStatus: %s\n\n## What it delivers\n\nthing\n\n## Acceptance\n\n- [ ] c\n' \
    "${1%%-*}" "$1" "$2" > "$E/tickets/$1.md"
}

# Feed the hook a payload and report its exit code.
fire() { # $1=file path  ->  exit code
  jq -n --arg cwd "$REPO" --arg f "$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $f}}' \
  | bash "$HOOK" >/dev/null 2>&1
  printf '%s' "$?"
}

ck() { # $1=desc $2=want-code $3=file
  local g; g=$(fire "$3")
  if [ "$g" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$1" "$2" "$g"; fi
}

ck_says() { # $1=desc $2=pattern $3=file
  local msg
  msg=$(jq -n --arg cwd "$REPO" --arg f "$3" \
    '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $f}}' | bash "$HOOK" 2>&1 >/dev/null)
  if printf '%s' "$msg" | grep -qE -- "$2"; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (message was: %s)\n' "$1" "$msg"; fi
}

# ── it fires ────────────────────────────────────────────────────────────────

echo "── a live effort on this branch with nothing taken"
setup work
mk 01-ready open
mk 02-later open
ck "editing code without a ticket is blocked" 2 "$REPO/src/app.ts"
ck_says "the refusal names the branch"        "work"        "$REPO/src/app.ts"
ck_says "and lists what is ready to take"     "01-ready"    "$REPO/src/app.ts"
ck_says "and names the command"               "ticket take" "$REPO/src/app.ts"

# ── it stays silent ─────────────────────────────────────────────────────────

echo "── with a ticket in progress"
setup work
mk 01-ready "in progress"
ck "work that belongs to a ticket goes through" 0 "$REPO/src/app.ts"

setup work
mk 01-ready open
mk 02-live "in progress"
ck "one ticket in progress is enough for the whole effort" 0 "$REPO/src/app.ts"

echo "── the map is how a ticket gets taken"
setup work
mk 01-ready open
ck "editing a ticket is never blocked"   0 "$E/tickets/01-ready.md"
ck "editing the map is never blocked"    0 "$E/map.md"
ck "editing the manifest is never blocked" 0 "$REPO/.devflow/project.yml"

echo "── scope"
setup work
mk 01-done done
mk 02-cancelled cancelled
ck "a finished effort gates nothing" 0 "$REPO/src/app.ts"

setup other-branch
mk 01-ready open
ck "an effort that does not name this branch gates nothing" 0 "$REPO/src/app.ts"

setup work
ck "an effort with no tickets at all gates nothing" 0 "$REPO/src/app.ts"

setup work
mk 01-ready open
rm -f "$REPO/.devflow/project.yml"
ck "outside a devflow project it says nothing" 0 "$REPO/src/app.ts"

setup work
mk 01-ready open
ck "a file outside the project is not its business" 0 "$SANDBOX/elsewhere.ts"

echo "── the branch is matched as a written name, not as a substring"
setup work
mk 01-ready open
printf '# alpha\n\nThe main working tree holds the map.\n' > "$E/map.md"
switch main
ck "prose that merely contains the word does not claim the branch" 0 "$REPO/src/app.ts"

setup work
mk 01-ready open
printf '# alpha\n\nРаботаем в ветке work, без кавычек.\n' > "$E/map.md"
ck "a map that does not write its branch in backticks leaves the gate silent" 0 "$REPO/src/app.ts"

setup feature/AIZHOL-431
mk 01-ready open
switch feature/AIZHOL-43
ck "a shorter branch does not claim a longer one's map" 0 "$REPO/src/app.ts"
switch feature/AIZHOL-431
ck "the branch the map names does claim it" 2 "$REPO/src/app.ts"

echo "── never on the base branch"
setup develop
mk 01-ready open
printf 'git:\n  base_branch: develop\n\nmaps:\n  dir: .devflow/maps\n' > "$REPO/.devflow/project.yml"
switch develop
ck "work does not happen on the base branch, so nothing is gated there" 0 "$REPO/src/app.ts"

echo "── notebooks are covered by the field they actually use"
setup work
mk 01-ready open
g=$(jq -n --arg cwd "$REPO" --arg f "$REPO/src/nb.ipynb" \
      '{tool_name: "NotebookEdit", cwd: $cwd, tool_input: {notebook_path: $f}}' \
    | bash "$HOOK" >/dev/null 2>&1; printf '%s' "$?")
if [ "$g" = "2" ]; then PASS=$((PASS+1)); printf '  ok   a notebook edit is gated like any other\n'
else FAIL=$((FAIL+1)); printf '  FAIL a notebook edit is gated like any other (got %s)\n' "$g"; fi

echo "── the bypass"
setup work
mk 01-ready open
g=$(jq -n --arg cwd "$REPO" --arg f "$REPO/src/app.ts" \
      '{tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $f}}' \
    | DEVFLOW_ALLOW=1 bash "$HOOK" >/dev/null 2>&1; printf '%s' "$?")
if [ "$g" = "0" ]; then PASS=$((PASS+1)); printf '  ok   DEVFLOW_ALLOW=1 in the environment disarms it\n'
else FAIL=$((FAIL+1)); printf '  FAIL DEVFLOW_ALLOW=1 in the environment disarms it (got %s)\n' "$g"; fi

echo "── it fails open"
setup work
mk 01-ready open
g=$(printf 'not json at all' | bash "$HOOK" >/dev/null 2>&1; printf '%s' "$?")
if [ "$g" = "0" ]; then PASS=$((PASS+1)); printf '  ok   an unreadable payload allows the edit\n'
else FAIL=$((FAIL+1)); printf '  FAIL an unreadable payload allows the edit (got %s)\n' "$g"; fi
g=$(jq -n '{tool_name: "Edit", cwd: "/nonexistent/nowhere", tool_input: {file_path: "/nonexistent/nowhere/a.ts"}}' \
    | bash "$HOOK" >/dev/null 2>&1; printf '%s' "$?")
if [ "$g" = "0" ]; then PASS=$((PASS+1)); printf '  ok   a directory that is gone allows the edit\n'
else FAIL=$((FAIL+1)); printf '  FAIL a directory that is gone allows the edit (got %s)\n' "$g"; fi
g=$(jq -n --arg cwd "$REPO" '{tool_name: "Edit", cwd: $cwd, tool_input: {}}' \
    | bash "$HOOK" >/dev/null 2>&1; printf '%s' "$?")
if [ "$g" = "0" ]; then PASS=$((PASS+1)); printf '  ok   a payload with no file path allows the edit\n'
else FAIL=$((FAIL+1)); printf '  FAIL a payload with no file path allows the edit (got %s)\n' "$g"; fi

echo "── synonyms are read, not reinterpreted"
setup work
mk 01-todo todo
ck "todo counts as a ticket ready to take" 2 "$REPO/src/app.ts"
setup work
mk 01-blocked blocked
ck "a blocked ticket is live work, and nothing is in progress" 2 "$REPO/src/app.ts"

echo
printf 'ticket-guard.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
