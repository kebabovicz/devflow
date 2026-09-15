#!/bin/bash
# Regression suite for `bin/devflow ticket take` and `ticket release`.
# Run via tests/run.sh or directly. Requires: bash, jq, git.
#
# Sandboxes only — never the real projects. The interesting test here is the
# race: several takes at once must produce exactly one winner, and a suite that
# ran against live tickets could not assert that without corrupting them.

set -u

CLI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/devflow"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

REPO="$SANDBOX/repo"
MAPS="$REPO/.devflow/maps"

setup() { # rebuilt before each group so one test never leaks into the next
  rm -rf "$REPO"
  mkdir -p "$MAPS/alpha/tickets"
  git -C "$REPO" init -q -b main 2>/dev/null
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
  printf 'maps:\n  dir: .devflow/maps\n' > "$REPO/.devflow/project.yml"

  mk 01-ready   open  none
  mk 02-blocked open  "01"
  mk 03-done    "done"  none
  mk 04-todo    todo  none
  mk 05-blocked-by-done open "03"

  cat > "$MAPS/alpha/tickets/06-questions.md" <<'T'
# 06 — ticket with an unanswered question

Blocked by: none
Status: open

## What it delivers

the payload endpoint

## Acceptance

- [ ] criterion

## Open questions

- which shape should the payload take?
T
}

mk() { # $1=name $2=status $3=blocked
  cat > "$MAPS/alpha/tickets/$1.md" <<T
# ${1%%-*} — $1

Blocked by: $3
Status: $2

## What it delivers

body

## Acceptance

- [ ] criterion
T
}

run() { ( cd "$REPO" && "$CLI" "$@" ); }

check_rc() { # $1=desc $2=want-rc $3...=args
  local desc="$1" want="$2"; shift 2
  run "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$want" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$desc"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$desc" "$want" "$rc"
  fi
}

check_json() { # $1=desc $2=want $3=filter $4...=args
  local desc="$1" want="$2" filter="$3"; shift 3
  local got; got=$(run "$@" 2>/dev/null | jq -r "$filter" 2>/dev/null)
  if [ "$got" = "$want" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$desc"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$desc" "$want" "$got"
  fi
}

check_file() { # $1=desc $2=want $3=file $4=key
  local got; got=$(grep -m1 "^$4:" "$3" 2>/dev/null | sed "s/^$4:[[:space:]]*//")
  if [ "$got" = "$2" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$got"
  fi
}

# ── the gate ────────────────────────────────────────────────────────────────

echo "── take: what may be taken"
setup
check_rc   "an open ticket is takeable"              0 ticket take 01-ready
check_file "taking sets Status in progress" "in progress" "$MAPS/alpha/tickets/01-ready.md" Status

setup
check_json "todo counts as open"       taken '.reason' ticket take 04-todo
setup
check_json "a done ticket is refused"  not_open '.reason' ticket take 03-done
check_rc   "refusal is code 3"         3 ticket take 03-done

setup
check_json "an unfinished blocker refuses" blocked_by '.reason' ticket take 02-blocked
check_json "the blocker is named"          1 '.blockers | length' ticket take 02-blocked
check_file "a refused take leaves Status alone" open "$MAPS/alpha/tickets/02-blocked.md" Status

setup
check_json "a done blocker does not refuse" taken '.reason' ticket take 05-blocked-by-done

setup
check_json "an unanswered question refuses" open_questions '.reason' ticket take 06-questions

echo "── take: references"
setup
check_json "a bare number resolves"   taken     '.reason' ticket take 01
check_json "an unknown ref refuses"   not_found '.reason' ticket take 99-nope
check_rc   "unknown ref is code 1"    1 ticket take 99-nope

echo "── take: the claim is exclusive"
setup
run ticket take 01-ready --owner first >/dev/null 2>&1
check_json "a second take conflicts" already_held '.reason' ticket take 01-ready --owner second
check_rc   "conflict is code 4"      4 ticket take 01-ready --owner second
check_json "the holder is named"     first '.holder' ticket take 01-ready --owner second

echo "── take: the race — one winner, no exceptions"
setup
OUT="$SANDBOX/race"; mkdir -p "$OUT"
for i in 1 2 3 4 5 6 7 8; do
  ( cd "$REPO" && "$CLI" ticket take 01-ready --owner "racer-$i" >"$OUT/$i.json" 2>&1; echo $? >"$OUT/$i.rc" ) &
done
wait
wins=$(grep -l '^0$' "$OUT"/*.rc 2>/dev/null | wc -l | tr -d ' ')
conflicts=$(grep -l '^4$' "$OUT"/*.rc 2>/dev/null | wc -l | tr -d ' ')
if [ "$wins" = "1" ]; then
  PASS=$((PASS+1)); printf '  ok   exactly one of 8 concurrent takes wins\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL exactly one of 8 concurrent takes wins (got %s winners)\n' "$wins"
fi
if [ "$conflicts" = "7" ]; then
  PASS=$((PASS+1)); printf '  ok   the other 7 are told it is held\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL the other 7 are told it is held (got %s conflicts)\n' "$conflicts"
fi

echo "── take: the legacy state — in progress with nobody holding it"
setup
sed -i.bak 's/^Status: open/Status: in progress/' "$MAPS/alpha/tickets/01-ready.md"
rm -f "$MAPS/alpha/tickets/01-ready.md.bak"
check_json "hand-set in progress is named, not claimed over" in_progress_unlocked '.reason' ticket take 01-ready

echo "── release"
setup
run ticket take 01-ready --owner first >/dev/null 2>&1
check_json "release reports the former holder" first '.was_held_by' ticket release 01-ready
check_json "release is idempotent"             false '.released' ticket release 01-ready
check_rc   "releasing nothing still succeeds"  0 ticket release 01-ready
check_file "release leaves Status untouched" "in progress" "$MAPS/alpha/tickets/01-ready.md" Status

setup
run ticket take 01-ready --owner first >/dev/null 2>&1
run ticket release 01-ready >/dev/null 2>&1
check_json "after release the status still says in progress, and that is named" \
  in_progress_unlocked '.reason' ticket take 01-ready

echo "── status shows the claim"
setup
run ticket take 01-ready --owner sess-a >/dev/null 2>&1
got=$(run status --json 2>/dev/null \
      | jq -r '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .lock.owner')
if [ "$got" = "sess-a" ]; then
  PASS=$((PASS+1)); printf '  ok   status reports the holder\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL status reports the holder (got %s)\n' "$got"
fi
got=$(run status --json 2>/dev/null \
      | jq -r '.repos[0].maps[0].tickets[] | select(.id=="03-done") | .lock')
if [ "$got" = "null" ]; then
  PASS=$((PASS+1)); printf '  ok   an unheld ticket has lock null\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL an unheld ticket has lock null (got %s)\n' "$got"
fi

echo "── environment"
OUTSIDE="$SANDBOX/outside"; mkdir -p "$OUTSIDE"
got=$( (cd "$OUTSIDE" && "$CLI" ticket take 01-ready) 2>/dev/null | jq -r '.reason' )
if [ "$got" = "not_onboarded" ]; then
  PASS=$((PASS+1)); printf '  ok   outside a devflow project it refuses\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL outside a devflow project it refuses (got %s)\n' "$got"
fi
(cd "$OUTSIDE" && "$CLI" ticket take 01-ready) >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then
  PASS=$((PASS+1)); printf '  ok   not onboarded is code 2\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL not onboarded is code 2 (got %s)\n' "$rc"
fi

echo
printf 'ticket-take.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
