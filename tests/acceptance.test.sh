#!/bin/bash
# Regression suite for `devflow ticket report` / `accept` — the boundary between
# what an executor claims and what a person accepted — and for the gate that
# keeps the state headers out of hand-typed markdown.
# Run via tests/run.sh or directly. Requires: bash, jq, git.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/devflow"
HOOK="$ROOT/hooks/ticket-guard.sh"
GUARD="$ROOT/hooks/guard.sh"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

REPO="$SANDBOX/repo"
E="$REPO/.devflow/maps/alpha"
T="$E/tickets"
SHA=""

setup() {
  rm -rf "$REPO"
  mkdir -p "$T" "$REPO/src"
  git -C "$REPO" init -q -b work 2>/dev/null
  printf 'code\n' > "$REPO/src/app.ts"
  git -C "$REPO" add -A 2>/dev/null
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q -m "the work" 2>/dev/null
  SHA=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)
  printf 'git:\n  base_branch: main\n\nmaps:\n  dir: .devflow/maps\n' > "$REPO/.devflow/project.yml"
  printf '# alpha\n\nВетка работы — `work`.\n' > "$E/map.md"
  mk 01-work "in progress" x
  mk 02-open open x
  mk 03-untick "in progress" " "
  mk 04-closed "done" x
}

mk() { # $1=name $2=status $3=tick char
  printf '# %s — %s\n\nBlocked by: none\nStatus: %s\n\n## What it delivers\n\nthing\n\n## Acceptance\n\n- [%s] a criterion\n\n## Open questions\n' \
    "${1%%-*}" "$1" "$2" "$3" > "$T/$1.md"
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

ck_hdr() { # $1=desc $2=key $3=want $4=file
  local g; g=$(grep -m1 "^$2:" "$4" 2>/dev/null | sed "s/^$2:[[:space:]]*//")
  if [ "$g" = "$3" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$1" "$3" "$g"; fi
}

ck_grep() { # $1=desc $2=pattern $3=file
  if grep -qE "$2" "$3" 2>/dev/null; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (pattern not found: %s)\n' "$1" "$2"; fi
}

# ── reporting ───────────────────────────────────────────────────────────────

echo "── report"
setup
ck "reporting succeeds"  reported '.reason' ticket report 01-work --commit "$SHA"
ck_hdr "the ticket is waiting on a person, not done" Status "awaiting review" "$T/01-work.md"
ck_grep "who reported it and against which commit" '^Reported: .* by .* commit ' "$T/01-work.md"
ck_hdr "it is not marked done" Status "awaiting review" "$T/01-work.md"

setup
ck_rc "a report with no commit is a bad invocation" 1 ticket report 01-work

setup
ck "a commit this repository does not have is refused" no_such_commit '.reason' \
  ticket report 01-work --commit deadbee
ck_rc "refusal is code 3" 3 ticket report 01-work --commit deadbee

setup
ck "unticked criteria are the claim not being made" acceptance_unticked '.reason' \
  ticket report 03-untick --commit "$SHA"
ck_hdr "and nothing was written" Status "in progress" "$T/03-untick.md"

setup
ck "a ticket nobody took has nothing to report" not_started '.reason' \
  ticket report 02-open --commit "$SHA"
setup
ck "a finished ticket has nothing to report" not_live '.reason' \
  ticket report 04-closed --commit "$SHA"

setup
run ticket report 01-work --commit "$SHA" >/dev/null 2>&1
ck "reporting twice says so" already_reported '.reason' ticket report 01-work --commit "$SHA"

echo "── report drops the claim, and only the holder may report"
setup
run ticket take 02-open --owner "session-a" >/dev/null 2>&1
ck "a different session cannot report someone else's ticket" not_holder '.reason' \
  ticket report 02-open --commit "$SHA" --owner "session-b"
ck_rc "that is a conflict, code 4" 4 ticket report 02-open --commit "$SHA" --owner "session-b"
ck "the holder can" reported '.reason' ticket report 02-open --commit "$SHA" --owner "session-a"
if [ -d "$E/.locks/02-open" ]; then
  FAIL=$((FAIL+1)); printf '  FAIL reporting drops the claim\n'
else
  PASS=$((PASS+1)); printf '  ok   reporting drops the claim\n'
fi

# ── accepting ───────────────────────────────────────────────────────────────

echo "── accept"
setup
run ticket report 01-work --commit "$SHA" >/dev/null 2>&1
ck "accepting succeeds"                 accepted '.reason' ticket accept 01-work --by "кебабович"
ck_hdr "only now is it done"             Status "done" "$T/01-work.md"
ck_grep "who accepted it is recorded"    '^Accepted: .* by кебабович$' "$T/01-work.md"
ck_grep "the report stays as the trail"  '^Reported: ' "$T/01-work.md"

setup
ck "nothing reported, nothing to accept" not_reported '.reason' ticket accept 01-work
ck_rc "refusal is code 3"                3 ticket accept 01-work
ck_hdr "and it stays in progress"        Status "in progress" "$T/01-work.md"

# A claim cannot normally outlive a report — reporting drops it. It can be left
# behind by a session that died between the two, and that is the case the check
# is for: accepting then would close the ticket out from under whoever picks the
# work back up.
setup
run ticket report 01-work --commit "$SHA" >/dev/null 2>&1
mkdir -p "$E/.locks/01-work"
printf 'session-b\n' > "$E/.locks/01-work/owner"
ck "a ticket somebody is holding is not a ticket to accept" still_held '.reason' ticket accept 01-work
ck_rc "that is a conflict, code 4" 4 ticket accept 01-work
ck_hdr "and it stays reported, not done" Status "awaiting review" "$T/01-work.md"

setup
run ticket report 01-work --commit "$SHA" >/dev/null 2>&1
run ticket accept 01-work >/dev/null 2>&1
ck "accepting twice says so" already_accepted '.reason' ticket accept 01-work

# ── what status reports ─────────────────────────────────────────────────────

echo "── status"
setup
ck "a ticket in flight has no acceptance state" none '.repos[0].maps[0].tickets[] | select(.id=="01-work") | .acceptance_state' status --json
ck "a ticket closed before this existed reads legacy" legacy '.repos[0].maps[0].tickets[] | select(.id=="04-closed") | .acceptance_state' status --json
setup
run ticket report 01-work --commit "$SHA" >/dev/null 2>&1
ck "a reported ticket reads reported" reported '.repos[0].maps[0].tickets[] | select(.id=="01-work") | .acceptance_state' status --json
run ticket accept 01-work --by "кебабович" >/dev/null 2>&1
ck "an accepted one reads accepted" accepted '.repos[0].maps[0].tickets[] | select(.id=="01-work") | .acceptance_state' status --json
ck "and says who"  "true" '.repos[0].maps[0].tickets[] | select(.id=="01-work") | (.accepted | test("кебабович"))' status --json

# ── the state headers are not text to type ──────────────────────────────────

fire() { # $1=file $2=payload field $3=payload  -> exit code
  jq -n --arg cwd "$REPO" --arg f "$1" --arg k "$2" --arg v "$3" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", cwd:$cwd,
      tool_input: ({file_path: $f} + {($k): $v})}' \
  | bash "$HOOK" >/dev/null 2>&1
  printf '%s' "$?"
}

ck_fire() { # $1=desc $2=want $3=file $4=field $5=payload
  local g; g=$(fire "$3" "$4" "$5")
  if [ "$g" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$1" "$2" "$g"; fi
}

echo "── hand-editing engine state"
setup
ck_fire "writing Status: done by hand is refused"  2 "$T/01-work.md" new_string "Status: done"
ck_fire "so is a whole-file write that changes it" 2 "$T/01-work.md" content \
  "# 01 — 01-work

Blocked by: none
Status: done

## Acceptance

- [x] a criterion"
ck_fire "and Accepted:, which nobody types"        2 "$T/01-work.md" new_string "Accepted: 2026-09-15T00:00:00Z by me"
ck_fire "and Contract:"                            2 "$T/01-work.md" new_string "Contract: approved 2026-09-15T00:00:00Z by me"

echo "── and the rest of the ticket is untouched"
ck_fire "editing what the ticket delivers goes through" 0 "$T/01-work.md" new_string "a better description of the work"
ck_fire "writing the same status back is not a change" 0 "$T/01-work.md" new_string "Status: in progress"
ck_fire "a ticket that does not exist yet is creation" 0 "$T/99-new.md" content \
  "# 99 — new

Blocked by: none
Status: open"
ck_fire "a file that is not a ticket is not this rule's business" 0 "$REPO/src/app.ts" new_string "Status: done"

echo "── the commands are still the way through"
setup
ck "question add still moves the status" asked '.reason' question add 01-work --text "?"
ck_hdr "to blocked" Status blocked "$T/01-work.md"

# ── a session does not accept its own work ──────────────────────────────────

echo "── guard 7"
gck() { # $1=desc $2=want-rc $3=command
  local rc
  printf '{"tool_input":{"command":%s},"cwd":%s}' \
    "$(printf '%s' "$3" | jq -Rs .)" "$(printf '%s' "$REPO" | jq -Rs .)" \
    | bash "$GUARD" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$1" "$2" "$rc"; fi
}
setup
gck "a session accepting its own work is blocked" 2 "devflow ticket accept 01-work"
gck "the user's explicit yes goes through"        0 "DEVFLOW_ALLOW=1 devflow ticket accept 01-work"
gck "reporting is the session's own job"          0 "devflow ticket report 01-work --commit abc1234"
gck "taking is untouched"                         0 "devflow ticket take 01-work"

echo
printf 'acceptance.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
