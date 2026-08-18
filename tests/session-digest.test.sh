#!/bin/bash
# Regression suite for hooks/session-digest.sh. Requires: bash, jq.
set -u

DIGEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/session-digest.sh"
PASS=0 FAIL=0

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

run() { # $1=cwd → stdout
  printf '{"cwd":%s}' "$(printf '%s' "$1" | jq -Rs .)" | "$DIGEST"
}

check() { # $1=description $2=condition-result
  if [ "$2" -eq 0 ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"
  fi
}

PROJ="$SANDBOX/proj"
mkdir -p "$PROJ/.devflow"
cat > "$PROJ/.devflow/project.yml" <<'EOF'
git:
  base_branch: "develop"        # quoted on purpose
  branch_pattern: feature/{key}
  commit_pattern: "{key}: {type}: {subject}"
EOF

out=$(run "$PROJ"); rc=$?
check "exits 0 in a devflow project" "$rc"
printf '%s' "$out" | grep -q "base branch 'develop'"; check "digest names the base branch (quotes stripped)" "$?"
printf '%s' "$out" | grep -q 'feature/{key}';          check "digest carries the branch pattern" "$?"
printf '%s' "$out" | grep -q 'persistent test state';  check "digest carries the data policy" "$?"

PLAIN="$SANDBOX/plain"; mkdir -p "$PLAIN"
out=$(run "$PLAIN"); rc=$?
check "exits 0 outside a devflow project" "$rc"
silent=0; [ -n "$out" ] && silent=1
check "stays silent outside a devflow project" "$silent"

MINIMAL="$SANDBOX/minimal"
mkdir -p "$MINIMAL/.devflow"
printf 'project:\n  name: x\n' > "$MINIMAL/.devflow/project.yml"
out=$(run "$MINIMAL"); rc=$?
check "exits 0 with a git-less manifest" "$rc"
! printf '%s' "$out" | grep -q 'base branch'
check "no git line when git section is absent" "$?"

# Conditional state lines — silent when clean, present when actionable.
out=$(run "$PROJ")
! printf '%s' "$out" | grep -q 'devflow manifest:'
check "no marker line on a clean manifest" "$?"

cat > "$PROJ/.devflow/project.yml" <<'EOF'
git:
  base_branch: develop
env:
  up: "npm run dev"  # UNVERIFIED — deferred
  health: []         # UNVERIFIED
auth:
  recipe: ""         # TODO: clarify
EOF
out=$(run "$PROJ")
printf '%s' "$out" | grep -q 'devflow manifest: 2 UNVERIFIED, 1 TODO'
check "marker line counts UNVERIFIED and TODO" "$?"

# ── Decision maps ──────────────────────────────────────────────────────────
out=$(run "$PROJ")
! printf '%s' "$out" | grep -q 'devflow map'
check "no map line without a map directory" "$?"

EFFORT="$PROJ/.devflow/maps/billing"
mkdir -p "$EFFORT/issues"
printf '# billing\n' > "$EFFORT/map.md"
# 01 resolved; 02 open and unblocked; 03 open but blocked by 04; 04 claimed.
printf 'Status: resolved\nBlocked by: none\n'  > "$EFFORT/issues/01-currency.md"
printf 'Status: open\nBlocked by: 01\n'        > "$EFFORT/issues/02-rounding.md"
printf 'Status: open\nBlocked by: 04\n'        > "$EFFORT/issues/03-refunds.md"
printf 'Status: claimed\nBlocked by: none\n'   > "$EFFORT/issues/04-invoices.md"
out=$(run "$PROJ")
printf '%s' "$out" | grep -q "devflow map 'billing': 3 open decision(s), 1 ready to take"
check "map line counts unresolved decisions and the takeable frontier" "$?"

# All decisions resolved but nothing cut yet → the map still owes its outputs.
printf 'Status: resolved\n' > "$EFFORT/issues/02-rounding.md"
printf 'Status: resolved\n' > "$EFFORT/issues/03-refunds.md"
printf 'Status: resolved\n' > "$EFFORT/issues/04-invoices.md"
out=$(run "$PROJ")
printf '%s' "$out" | grep -q "devflow map 'billing': every decision resolved, no tickets cut yet"
check "map line nags when decisions are done but tickets are not cut" "$?"

# Implementation tickets exist → the line switches to what is left to build.
mkdir -p "$EFFORT/tickets"
printf 'Status: done\n' > "$EFFORT/tickets/01-schema.md"
printf 'Status: open\n' > "$EFFORT/tickets/02-endpoint.md"
out=$(run "$PROJ")
printf '%s' "$out" | grep -q "devflow map 'billing': decisions settled, 1 implementation ticket(s) left"
check "map line switches to implementation tickets once decisions are settled" "$?"

printf 'Status: done\n' > "$EFFORT/tickets/02-endpoint.md"
out=$(run "$PROJ")
! printf '%s' "$out" | grep -q 'devflow map'
check "no map line when the whole effort is done" "$?"

# A custom maps.dir in the manifest is honored.
CUSTOM="$SANDBOX/custom"
mkdir -p "$CUSTOM/.devflow" "$CUSTOM/planning/search/issues"
printf 'maps:\n  dir: planning\n' > "$CUSTOM/.devflow/project.yml"
printf '# search\n' > "$CUSTOM/planning/search/map.md"
printf 'Status: open\nBlocked by: none\n' > "$CUSTOM/planning/search/issues/01-scope.md"
out=$(run "$CUSTOM")
printf '%s' "$out" | grep -q "devflow map 'search': 1 open decision(s), 1 ready to take"
check "map line honors a custom maps.dir" "$?"

echo
echo "session-digest.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
