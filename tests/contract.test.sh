#!/bin/bash
# Regression suite for `bin/devflow contract draft | approve` and the gate it
# puts in front of `ticket take`. Run via tests/run.sh or directly.
# Requires: bash, jq, git.
#
# Sandboxes only. The cases that matter: a ticket cut before contracts existed
# stays takeable; a ticket that never says how anyone would know it is done does
# not; approval is recorded with who and when; and drafting over an approval
# withdraws it.

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
  # Cut before contracts had a name: both sections filled, no header.
  mk_full 01-legacy open
  # Cut with the header the format now carries.
  mk_full 02-draft open
  printf '%s\n' "Contract: draft" >> "$T/02-draft.md"
  # Says nothing about delivery and carries no criterion.
  cat > "$T/03-bare.md" <<'X'
# 03 — bare

Blocked by: none
Status: open

## What it delivers

## Acceptance

## Open questions
X
  mk_full 04-done done
}

mk_full() { # $1=name $2=status
  cat > "$T/$1.md" <<X
# ${1%%-*} — $1

Blocked by: none
Status: $2

## What it delivers

the end-to-end thing

## Acceptance

- [ ] a mechanically checkable criterion

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

ck_grep() { # $1=desc $2=pattern $3=file
  if grep -qE "$2" "$3" 2>/dev/null; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (pattern not found: %s)\n' "$1" "$2"; fi
}

ck_state() { # $1=desc $2=want $3=ticket id
  local g
  g=$(run status --json 2>/dev/null \
      | jq -r --arg i "$3" '.repos[0].maps[0].tickets[] | select(.id==$i) | .contract.state')
  if [ "$g" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$g"; fi
}

# ── what the four states are ────────────────────────────────────────────────

echo "── status reports the contract of every ticket"
setup
ck_state "a ticket with both sections and no header reads legacy" legacy 01-legacy
ck_state "an explicit draft reads draft"                          draft  02-draft
ck_state "a ticket with neither section reads none"               none   03-bare

# ── the gate ────────────────────────────────────────────────────────────────

echo "── take"
setup
ck "a ticket cut before contracts existed stays takeable" taken '.reason' ticket take 01-legacy

setup
ck "a draft contract stops the work" contract_unapproved '.reason' ticket take 02-draft
ck "the refusal names the state"     draft '.contract'    ticket take 02-draft
ck_rc "refusal is code 3"            3 ticket take 02-draft

setup
ck "no contract stops the work"  contract_unapproved '.reason' ticket take 03-bare
ck "the refusal names the state" none '.contract'              ticket take 03-bare

setup
run contract approve 02-draft --by "кебабович" >/dev/null 2>&1
ck "approval opens the ticket for work" taken '.reason' ticket take 02-draft

echo "── the status gate still answers first where it is the better answer"
setup
ck "a finished ticket is refused as not open, not as unapproved" not_open '.reason' ticket take 04-done

# ── drafting ────────────────────────────────────────────────────────────────

echo "── draft"
setup
ck "drafting a ticket that says nothing about delivery is refused" \
  contract_incomplete '.reason' contract draft 03-bare
ck_rc "refusal is code 3" 3 contract draft 03-bare
ck_state "the refusal wrote nothing" none 03-bare

setup
ck "delivery without a criterion is still not a contract" \
  contract_incomplete '.reason' contract draft 03-bare --delivers "a list endpoint"

setup
ck "prose where a checklist belongs is refused" \
  contract_incomplete '.reason' contract draft 03-bare \
  --delivers "a list endpoint" --acceptance "it should work"

setup
printf -- '- [ ] GET /x returns 200\n- [ ] the list is paged\n' \
  | ( cd "$REPO" && "$CLI" contract draft 03-bare --delivers "a list endpoint" --acceptance - ) >/dev/null 2>&1
ck_state "a complete contract is written as a draft" draft 03-bare
ck_grep "what it delivers is written" '^a list endpoint$'        "$T/03-bare.md"
ck_grep "the criteria are written"    '^- \[ \] the list is paged$' "$T/03-bare.md"
# A written section must not run into the heading that follows it: the ticket is
# a document someone reads, and the blank line is part of how it reads.
if awk '/^a list endpoint$/ { getline nxt; if (nxt == "") ok = 1 } END { exit !ok }' "$T/03-bare.md"; then
  PASS=$((PASS+1)); printf '  ok   a blank line still separates the section from the next heading\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL a blank line still separates the section from the next heading\n'
fi

setup
ck "marking a ticket that already says both is enough" drafted '.reason' contract draft 01-legacy
ck_state "it becomes an explicit draft" draft 01-legacy

setup
ck "a finished ticket is past agreeing" not_live '.reason' contract draft 04-done

setup
run contract approve 01-legacy >/dev/null 2>&1
ck "drafting over an approval withdraws it" approved '.was' contract draft 01-legacy
ck_state "and leaves it a draft" draft 01-legacy

setup
ck_rc "reading both bodies from stdin is refused as a bad invocation" \
  1 contract draft 03-bare --delivers - --acceptance -

# ── approving ───────────────────────────────────────────────────────────────

echo "── approve"
setup
ck "approving a draft succeeds"     approved '.reason' contract approve 02-draft
ck_state "the state becomes approved" approved 02-draft
setup
run contract approve 02-draft --by "кебабович" >/dev/null 2>&1
ck_grep "who approved it is recorded" '^Contract: approved .* by кебабович$' "$T/02-draft.md"
ck "status reports who approved"  "кебабович" \
  '.repos[0].maps[0].tickets[] | select(.id=="02-draft") | .contract.by' status --json
ck "status reports when"  "true" \
  '.repos[0].maps[0].tickets[] | select(.id=="02-draft") | (.contract.at != null)' status --json

setup
run contract approve 01-legacy >/dev/null 2>&1
ck "approving twice is not an error" already_approved '.reason' contract approve 01-legacy
ck_rc "and it succeeds" 0 contract approve 01-legacy

setup
ck "there is nothing to approve on a bare ticket" no_contract '.reason' contract approve 03-bare
ck_rc "refusal is code 3" 3 contract approve 03-bare

echo "── the human line says a contract is waiting"
setup
got=$(run status 2>/dev/null | head -1)
case "$got" in
  *"контрактов на одобрение: 1"*) PASS=$((PASS+1)); printf '  ok   a draft is reported to a person, not only in JSON\n' ;;
  *) FAIL=$((FAIL+1)); printf '  FAIL a draft is reported to a person (got %s)\n' "$got" ;;
esac

echo "── the ticket is edited, not rewritten"
setup
cp "$T/01-legacy.md" "$SANDBOX/before.md"
run contract approve 01-legacy >/dev/null 2>&1
if diff <(grep -v '^Contract:' "$T/01-legacy.md") "$SANDBOX/before.md" >/dev/null 2>&1; then
  PASS=$((PASS+1)); printf '  ok   approval adds one line and touches nothing else\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL approval adds one line and touches nothing else\n'
  diff <(grep -v '^Contract:' "$T/01-legacy.md") "$SANDBOX/before.md" | head -5
fi
if awk '/^Status:/ { getline nxt; if (nxt ~ /^Contract: /) ok = 1 } END { exit !ok }' "$T/01-legacy.md"; then
  PASS=$((PASS+1)); printf '  ok   the new header sits in the header block, under Status\n'
else
  FAIL=$((FAIL+1)); printf '  FAIL the new header sits in the header block, under Status\n'
fi

echo
printf 'contract.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
