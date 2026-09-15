#!/bin/bash
# Regression suite for `bin/devflow status`. Run via tests/run.sh or directly.
# Requires: bash, jq, git.
#
# Everything runs against sandboxes built here — never the real projects. Live
# maps change, and a suite that reads them fails for reasons that have nothing
# to do with the code.

set -u

CLI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/devflow"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

# ── fixtures ────────────────────────────────────────────────────────────────

# A devflow repo with two maps: one carrying tickets across several statuses
# (including the `todo` and `cancelled` values live files actually use, which
# the documented format does not list), one charted but not yet sliced.
FULL="$SANDBOX/full"
mkdir -p "$FULL/.devflow/maps/alpha/tickets" \
         "$FULL/.devflow/maps/alpha/issues" \
         "$FULL/.devflow/maps/beta"
git -C "$FULL" init -q -b main
git -C "$FULL" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
printf 'maps:\n  dir: .devflow/maps\n' > "$FULL/.devflow/project.yml"

mk_ticket() { # $1=file $2=status $3=blocked $4=extra-body
  cat > "$1" <<TICKET
# 0${1##*/} — заголовок тикета

Blocked by: $3
Status: $2

## What it delivers

тело

## Acceptance

- [x] первый критерий
- [ ] второй критерий
${4:-}
TICKET
}

mk_ticket "$FULL/.devflow/maps/alpha/tickets/01-a.md" "done" none
mk_ticket "$FULL/.devflow/maps/alpha/tickets/02-b.md" todo none
mk_ticket "$FULL/.devflow/maps/alpha/tickets/03-c.md" cancelled "01, 02"
mk_ticket "$FULL/.devflow/maps/alpha/tickets/04-d.md" "in progress" "01"

printf '# 01 — открытый вопрос\n\nType: research\nStatus: open\n' \
  > "$FULL/.devflow/maps/alpha/issues/01-q.md"
printf '# 02 — решённый вопрос\n\nType: research\nStatus: resolved\n' \
  > "$FULL/.devflow/maps/alpha/issues/02-q.md"
printf '# beta\n\n## Destination\n\nещё не нарезана\n' \
  > "$FULL/.devflow/maps/beta/map.md"

# A git repo that never onboarded devflow.
BARE="$SANDBOX/bare"
mkdir -p "$BARE"
git -C "$BARE" init -q -b main
git -C "$BARE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

# A plain directory: no git, no devflow.
PLAIN="$SANDBOX/plain"; mkdir -p "$PLAIN"

# ── helpers ─────────────────────────────────────────────────────────────────

check() { # $1=description $2=expected $3=jq-filter $4...=paths
  local desc="$1" want="$2" filter="$3"; shift 3
  local got
  got=$("$CLI" status --json "$@" 2>/dev/null | jq -r "$filter" 2>/dev/null)
  if [ "$got" = "$want" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$desc"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$desc" "$want" "$got"
  fi
}

check_rc() { # $1=description $2=expected-rc $3...=args
  local desc="$1" want="$2"; shift 2
  "$CLI" status "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$want" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$desc"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$desc" "$want" "$rc"
  fi
}

# ── the contract ────────────────────────────────────────────────────────────

echo "── status: shape"
check "schema is declared"        1 '.schema' "$FULL"
check "one repo per path"         3 '.repos | length' "$FULL" "$BARE" "$PLAIN"

echo "── status: engine present or not"
check "engine true with manifest"    true  '.repos[0].engine' "$FULL"
check "engine false without manifest" false '.repos[0].engine' "$BARE"
check "engine false in plain dir"     false '.repos[0].engine' "$PLAIN"

echo "── status: branch"
check "branch reported"        main '.repos[0].branch' "$FULL"
check "branch null off git"    null '.repos[0].branch' "$PLAIN"

echo "── status: maps and tickets"
check "both maps listed"       2  '.repos[0].maps | length' "$FULL"
check "unsliced map kept"      0  '.repos[0].maps[] | select(.slug=="beta") | .tickets | length' "$FULL"
check "tickets counted"        4  '.repos[0].tickets_total' "$FULL"

echo "── status: the drift between documented and live status values"
check "todo normalizes to open"  open '.repos[0].maps[] | select(.slug=="alpha") | .tickets[] | select(.id=="02-b") | .status' "$FULL"
check "raw value is preserved"   todo '.repos[0].maps[] | select(.slug=="alpha") | .tickets[] | select(.id=="02-b") | .status_raw' "$FULL"
check "cancelled survives"       1 '.repos[0].counts.cancelled' "$FULL"
check "in progress survives"     1 '.repos[0].counts["in progress"]' "$FULL"

echo "── status: dependency edges"
check "blocked_by parsed as list" 2 '.repos[0].maps[] | select(.slug=="alpha") | .tickets[] | select(.id=="03-c") | .blocked_by | length' "$FULL"
check "none becomes empty list"   0 '.repos[0].maps[] | select(.slug=="alpha") | .tickets[] | select(.id=="01-a") | .blocked_by | length' "$FULL"

echo "── status: acceptance is the implementer's claim, counted not trusted"
check "acceptance total"   2 '.repos[0].maps[] | select(.slug=="alpha") | .tickets[] | select(.id=="01-a") | .acceptance.total' "$FULL"
check "acceptance checked" 1 '.repos[0].maps[] | select(.slug=="alpha") | .tickets[] | select(.id=="01-a") | .acceptance.checked' "$FULL"

echo "── status: questions waiting on a human"
check "open and claimed count"  1 '.repos[0].questions_open' "$FULL"
check "resolved does not count" 1 '.repos[0].maps[] | select(.slug=="alpha") | .questions_open' "$FULL"

echo "── status: session link is honest about not existing yet"
check "session is null" null '.repos[0].maps[] | select(.slug=="alpha") | .tickets[0] | .session' "$FULL"

echo "── status: return codes"
check_rc "a repo without devflow is not an error" 0 "$BARE"
check_rc "a plain directory is not an error"      0 "$PLAIN"
check_rc "a missing path is a bad invocation"     1 "$SANDBOX/nope"
check_rc "an unknown option is a bad invocation"  1 --wat

# ── verdict ─────────────────────────────────────────────────────────────────

echo
printf 'status.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
