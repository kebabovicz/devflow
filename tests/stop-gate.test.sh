#!/bin/bash
# Regression suite for hooks/ralph-stop-gate.sh — the doctor layer-1 self-test
# cases, committed. Run via tests/run.sh or directly. Requires: bash, jq, git.
set -u

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/ralph-stop-gate.sh"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

check() { # $1=expected-exit $2=cwd $3=stop_hook_active $4=description
  local out rc
  out=$(printf '{"cwd":%s,"stop_hook_active":%s}' \
        "$(printf '%s' "$2" | jq -Rs .)" "$3" | "$GATE" 2>&1); rc=$?
  if [ "$rc" -eq "$1" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$4"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n       out: %s\n' "$4" "$1" "$rc" "$out"
  fi
}

# Ralph project: manifest with ralph.todo, TODO committed, then dirtied.
PROJ="$SANDBOX/ralph"
mkdir -p "$PROJ/.devflow"
git -C "$PROJ" init -q -b feature/x
printf 'ralph:\n  todo: .devflow/TODO.md\n' > "$PROJ/.devflow/project.yml"
printf -- '- [ ] task one\n' > "$PROJ/.devflow/TODO.md"

echo "stop-gate"
check 2 "$PROJ" false "untracked TODO blocks (one-time nudge — commit the plan)"

git -C "$PROJ" add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm init
check 0 "$PROJ" false "clean tree allows stop"

printf -- '- [x] task one — done\n' > "$PROJ/.devflow/TODO.md"
check 2 "$PROJ" false "dirty TODO blocks stop"
check 0 "$PROJ" true  "stop_hook_active=true always allows (loop protection)"

git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qam "task done"
check 0 "$PROJ" false "committed checkmark allows stop"

PLAIN="$SANDBOX/plain"; mkdir -p "$PLAIN"
check 0 "$PLAIN" false "no manifest => gate inactive"

echo
echo "stop-gate.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
