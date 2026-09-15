#!/bin/bash
# Regression suite for `bin/devflow session start` and the session fields it
# puts into `status`. Run via tests/run.sh or directly.
# Requires: bash, jq, git.
#
# No real session is ever started here. A stub `claude` sits first on PATH,
# records the arguments it was given, and answers `agents --json` from a fixture
# — so the test can assert exactly what would have been run, which is the part
# that has to stay right.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/devflow"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

REPO="$SANDBOX/repo"
T="$REPO/.devflow/maps/alpha/tickets"
BIN="$SANDBOX/bin"
ARGV="$SANDBOX/argv"
REGISTRY="$SANDBOX/registry.json"

# ── the stub ────────────────────────────────────────────────────────────────

mkdir -p "$BIN"
cat > "$BIN/claude" <<'STUB'
#!/bin/bash
# Stands in for the real CLI. Records its argv, answers the two calls the engine
# makes, and fails on demand so the rollback path can be tested.
printf '%s\n' "$*" >> "$ARGV"
case "${1:-}" in
  agents)
    cat "$REGISTRY"
    exit 0 ;;
esac
if [ "${STUB_FAIL:-0}" = "1" ]; then
  printf 'something went wrong\n' >&2
  exit 1
fi
# The real thing prints the id decorated with colour, and the name after it.
name=""
while [ $# -gt 0 ]; do
  case "$1" in -n) name="${2:-}"; shift 2 ;; *) shift ;; esac
done
printf 'backgrounded · \033[36mdeadbeef\033[39m · %s\n' "$name"
STUB
chmod +x "$BIN/claude"
export PATH="$BIN:$PATH"
export ARGV REGISTRY

registry_empty() { printf '[]\n' > "$REGISTRY"; }

registry_with() { # $1=how many live sessions, plus one dead one
  local n="$1" i out="["
  for ((i = 0; i < n; i++)); do
    [ "$i" -gt 0 ] && out="$out,"
    out="$out{\"pid\": $((5000 + i)), \"cwd\": \"$REPO\", \"kind\": \"background\", \"startedAt\": 1788877244429, \"sessionId\": \"live$i-aaaa-bbbb\", \"name\": \"s$i\", \"status\": \"busy\"}"
  done
  [ "$n" -gt 0 ] && out="$out,"
  # An exited session stays in the registry with a null pid. It must not count.
  out="$out{\"pid\": null, \"cwd\": \"$REPO\", \"kind\": \"background\", \"startedAt\": 1788877244429, \"sessionId\": \"deadbeef-cccc-dddd\", \"name\": \"01-ready\", \"status\": null}]"
  printf '%s\n' "$out" > "$REGISTRY"
}

registry_running_deadbeef() {
  printf '[{"pid": 4242, "cwd": "%s", "kind": "background", "startedAt": 1788877244429, "sessionId": "deadbeef-cccc-dddd", "name": "01-ready", "status": "busy"}]\n' \
    "$REPO" > "$REGISTRY"
}

# ── the project ─────────────────────────────────────────────────────────────

setup() { # $1=sessions.worktree $2=sessions.limit
  rm -rf "$REPO"
  mkdir -p "$T"
  git -C "$REPO" init -q -b main 2>/dev/null
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
  cat > "$REPO/.devflow/project.yml" <<Y
sessions:
  worktree: ${1:-false}
  limit: ${2:-0}

maps:
  dir: .devflow/maps
Y
  mk 01-ready open
  mk 02-other open
  : > "$ARGV"
  registry_empty
}

mk() { # $1=name $2=status
  cat > "$T/$1.md" <<X
# ${1%%-*} — $1

Blocked by: none
Status: $2

## What it delivers

the end-to-end thing

## Acceptance

- [ ] a checkable criterion

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

ck_argv() { # $1=desc $2=pattern (extended regex)
  if grep -qE -- "$2" "$ARGV" 2>/dev/null; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n       argv was: %s\n' "$1" "$(tail -1 "$ARGV")"; fi
}

ck_no_argv() { # $1=desc $2=pattern
  if grep -qE -- "$2" "$ARGV" 2>/dev/null; then
    FAIL=$((FAIL+1)); printf '  FAIL %s\n       argv was: %s\n' "$1" "$(tail -1 "$ARGV")"
  else PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; fi
}

ck_status_hdr() { # $1=desc $2=want $3=file
  local g; g=$(grep -m1 '^Status:' "$3" 2>/dev/null | sed 's/^Status:[[:space:]]*//')
  if [ "$g" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$g"; fi
}

# ── starting ────────────────────────────────────────────────────────────────

echo "── what gets run"
setup false 0
ck "starting succeeds"            started  '.reason'  session start 01-ready
ck "the session id is reported"   deadbeef '.session' session start 02-other
ck_argv "the session is backgrounded"            '(^| )--bg( |$)'
ck_argv "it is named after the ticket"           '\-n 02-other'
ck_argv "the task skill is the opening prompt"   '/devflow:task '
ck_argv "the ticket path is absolute"            "/devflow:task $SANDBOX/"
ck_no_argv "no worktree unless the project asks for one" '(^| )-w( |$)'

setup true 0
run session start 01-ready >/dev/null 2>&1
ck_argv "sessions.worktree: true asks for a worktree" '\-w 01-ready'
ck "and the answer says so" true '.worktree' session start 02-other

setup false 0
ck "the name can be overridden" started '.reason' session start 01-ready --name "рефакторинг"
ck_argv "the given name is used" '\-n рефакторинг'

echo "── the claim"
setup false 0
run session start 01-ready >/dev/null 2>&1
ck_status_hdr "the ticket is marked in progress" "in progress" "$T/01-ready.md"
if [ -f "$REPO/.devflow/maps/alpha/.locks/01-ready/session" ]; then
  PASS=$((PASS+1)); printf '  ok   the session id is written into the claim\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL the session id is written into the claim\n'
fi
ck "starting a second time hits the claim" already_held '.reason' session start 01-ready
ck_rc "and that is a conflict, code 4" 4 session start 01-ready

echo "── the gates take enforces apply unchanged"
setup false 0
printf '%s\n' "Contract: draft" >> "$T/01-ready.md"
ck "an unapproved contract stops the dispatch" contract_unapproved '.reason' session start 01-ready
ck_no_argv "and nothing was started" '(^| )--bg( |$)'

setup false 0
run question add 01-ready --text "?" >/dev/null 2>&1
: > "$ARGV"
ck "an open question stops the dispatch" not_open '.reason' session start 01-ready
ck_no_argv "and nothing was started" '(^| )--bg( |$)'

# ── the limit ───────────────────────────────────────────────────────────────

echo "── sessions.limit"
setup false 2
registry_with 2
ck "at the limit the dispatch is refused" session_limit '.reason' session start 01-ready
ck "the refusal says how many are running" 2 '.running' session start 01-ready
ck_rc "refusal is code 3" 3 session start 01-ready
ck_status_hdr "and the ticket was not claimed" "open" "$T/01-ready.md"

setup false 2
registry_with 1
ck "below the limit it runs" started '.reason' session start 01-ready

setup false 1
registry_with 0
ck "an exited session does not count against the limit" started '.reason' session start 01-ready

setup false 0
registry_with 5
ck "limit 0 means no limit" started '.reason' session start 01-ready

# ── failure ─────────────────────────────────────────────────────────────────

echo "── when the session cannot be started"
setup false 0
STUB_FAIL=1 run session start 01-ready >/dev/null 2>&1
ck_status_hdr "the claim is given back, not left in progress" "open" "$T/01-ready.md"
if [ -d "$REPO/.devflow/maps/alpha/.locks/01-ready" ]; then
  FAIL=$((FAIL+1)); printf '  FAIL the lock is removed too\n'
else
  PASS=$((PASS+1)); printf '  ok   the lock is removed too\n'
fi
setup false 0
g=$(cd "$REPO" && STUB_FAIL=1 "$CLI" session start 01-ready 2>/dev/null | jq -r '.reason')
if [ "$g" = "spawn_failed" ]; then PASS=$((PASS+1)); printf '  ok   the failure is reported as spawn_failed\n'
else FAIL=$((FAIL+1)); printf '  FAIL the failure is reported as spawn_failed (got %s)\n' "$g"; fi

# ── what status says afterwards ─────────────────────────────────────────────

echo "── status joins the ticket to its session"
setup false 0
run session start 01-ready >/dev/null 2>&1
registry_running_deadbeef
ck "the ticket names its session" deadbeef \
  '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .session.id' status --json
ck "and reports what it is doing" busy \
  '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .session.status' status --json
ck "a claim held by a live session is not stale" false \
  '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .lock.stale' status --json
ck "the repository lists its sessions" 1 \
  '.repos[0].sessions | length' status --json
ck "an untouched ticket has no session" null \
  '.repos[0].maps[0].tickets[] | select(.id=="02-other") | .session' status --json

setup false 0
run session start 01-ready >/dev/null 2>&1
registry_empty
ck "once the session is gone the claim reads stale" true \
  '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .lock.stale' status --json
ck "and the session it named is no longer there" null \
  '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .session' status --json
ck "the claim still says which session held it" deadbeef \
  '.repos[0].maps[0].tickets[] | select(.id=="01-ready") | .lock.session' status --json

echo
printf 'session-start.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
