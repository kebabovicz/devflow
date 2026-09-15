#!/bin/bash
# Regression suite for `bin/devflow question add | answer | drop`.
# Run via tests/run.sh or directly. Requires: bash, jq, git.
#
# Sandboxes only. The cases that matter: a question blocks the ticket and the
# status it had is restored when the question is settled; settled questions stay
# in the file but stop blocking; a multi-line markdown body survives the trip.

set -u

CLI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/devflow"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

REPO="$SANDBOX/repo"
MAPS="$REPO/.devflow/maps"
T="$MAPS/alpha/tickets"

setup() {
  rm -rf "$REPO"
  mkdir -p "$T"
  git -C "$REPO" init -q -b main 2>/dev/null
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
  printf 'maps:\n  dir: .devflow/maps\n' > "$REPO/.devflow/project.yml"
  mk 01-open open
  mk 02-done "done"
  mk 03-prog "in progress"
  # A ticket cut before questions had commands: the old one-line bullet form.
  cat > "$T/04-legacy.md" <<'X'
# 04 — legacy question form

Blocked by: none
Status: open

## What it delivers

the token store

## Acceptance

- [ ] criterion

## Open questions

- from 02, while implementing: the token is per device — decide before this
X
}

mk() { # $1=name $2=status
  cat > "$T/$1.md" <<X
# ${1%%-*} — $1

Blocked by: none
Status: $2

## What it delivers

body

## Acceptance

- [ ] criterion

## Open questions
X
}

run() { ( cd "$REPO" && "$CLI" "$@" ); }

ck() { # $1=desc $2=want $3=filter $4...=args
  local d="$1" w="$2" f="$3"; shift 3
  local g; g=$(run "$@" 2>/dev/null | jq -r "$f" 2>/dev/null)
  if [ "$g" = "$w" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$d"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$d" "$w" "$g"; fi
}

ck_rc() { # $1=desc $2=want-rc $3...=args
  local d="$1" w="$2"; shift 2
  run "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$w" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$d"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$d" "$w" "$rc"; fi
}

ck_status() { # $1=desc $2=want $3=ticket file
  local g; g=$(grep -m1 '^Status:' "$3" 2>/dev/null | sed 's/^Status:[[:space:]]*//')
  if [ "$g" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$g"; fi
}

ck_grep() { # $1=desc $2=pattern $3=file
  if grep -qE "$2" "$3" 2>/dev/null; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (pattern not found: %s)\n' "$1" "$2"; fi
}

# ── asking ──────────────────────────────────────────────────────────────────

echo "── add"
setup
ck "asking succeeds"            asked '.reason' question add 01-open --text "which cursor format?"
ck_status "the ticket is blocked" blocked "$T/01-open.md"
ck_grep "the heading records the state and the status to restore" \
  '^### Q1 · open · asked .* · was: open' "$T/01-open.md"
ck_grep "the body is written verbatim" 'which cursor format\?' "$T/01-open.md"

setup
ck "a finished ticket waits on nobody" not_live '.reason' question add 02-done --text "too late"
ck_rc "refusal is code 3" 3 question add 02-done --text "too late"

setup
ck "the status in progress is recorded, not lost" asked '.reason' question add 03-prog --text "?"
ck_grep "was: in progress" 'was: in progress' "$T/03-prog.md"

echo "── add: a multi-line body from stdin"
setup
printf '**Ein Beschluss zur Seitengröße wird gebraucht.**\n\n1. Cursor — stabil beim Einfügen.\n2. Offset — einfacher.\n\nVorschlag: 1.\n' \
  | ( cd "$REPO" && "$CLI" question add 01-open --text - ) >/dev/null 2>&1
ck_grep "the bold first line survives"  '^\*\*Ein Beschluss zur Seitengröße wird gebraucht\.\*\*$' "$T/01-open.md"
ck_grep "the numbered options survive"  '^2\. Offset — einfacher\.$'                    "$T/01-open.md"
ck_grep "the proposal survives"         '^Vorschlag: 1\.$'                          "$T/01-open.md"

# ── answering ───────────────────────────────────────────────────────────────

echo "── answer"
setup
run question add 01-open --text "which cursor format?" >/dev/null 2>&1
ck "answering succeeds"           answered '.reason' question answer 01-open --text "base64 of the pair"
ck_status "the prior status is restored, not guessed" open "$T/01-open.md"
ck_grep "the heading now says answered" '^### Q1 · answered .* · asked ' "$T/01-open.md"
ck_grep "the question body stays"       'which cursor format\?'        "$T/01-open.md"
ck_grep "the answer is written"         'base64 of the pair'                "$T/01-open.md"

setup
run question add 03-prog --text "?" >/dev/null 2>&1
run question answer 03-prog --text "yes" >/dev/null 2>&1
ck_status "in progress is restored, not open" "in progress" "$T/03-prog.md"

setup
run question add 01-open --text "first" >/dev/null 2>&1
run question add 01-open --text "second" >/dev/null 2>&1
ck "answering one of two leaves one open" 1 '.still_open' question answer 01-open --text "an answer"
ck_status "the ticket stays blocked while one waits" blocked "$T/01-open.md"

setup
run question add 01-open --text "first"  >/dev/null 2>&1
run question add 01-open --text "second"  >/dev/null 2>&1
run question answer 01-open --question Q2 --text "on the second" >/dev/null 2>&1
ck_grep "the named question is the one answered" '^### Q2 · answered' "$T/01-open.md"
ck_grep "the other stays open"                   '^### Q1 · open'     "$T/01-open.md"

setup
ck "answering nothing is refused"  nothing_open '.reason' question answer 01-open --text "x"
ck_rc "refusal is code 3"          3 question answer 01-open --text "x"

# ── dropping ────────────────────────────────────────────────────────────────

echo "── drop"
setup
run question add 01-open --text "changed my mind about asking" >/dev/null 2>&1
ck "dropping succeeds"             dropped '.reason' question drop 01-open
ck_status "the status is restored" open "$T/01-open.md"
ck_grep "the heading says dropped" '^### Q1 · dropped ' "$T/01-open.md"
ck_grep "the body is kept as history" 'changed my mind about asking' "$T/01-open.md"

# ── how this reaches the rest of the engine ─────────────────────────────────

echo "── take sees questions, and only the open ones"
setup
run question add 01-open --text "?" >/dev/null 2>&1
ck "a blocked ticket cannot be taken" not_open '.reason' ticket take 01-open

setup
run question add 01-open --text "?" >/dev/null 2>&1
run question answer 01-open --text "!" >/dev/null 2>&1
ck "a settled question no longer blocks a take" taken '.reason' ticket take 01-open

setup
ck "the old one-line form still counts as open" open_questions '.reason' ticket take 04-legacy

echo "── status reports questions per ticket"
setup
run question add 01-open --text "?" >/dev/null 2>&1
got=$(run status --json 2>/dev/null | jq -r '.repos[0].maps[0].tickets[] | select(.id=="01-open") | .status')
if [ "$got" = "blocked" ]; then
  PASS=$((PASS+1)); printf '  ok   status shows the ticket as blocked\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL status shows the ticket as blocked (got %s)\n' "$got"
fi

echo
printf 'question.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
