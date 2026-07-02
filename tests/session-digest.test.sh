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

echo
echo "session-digest.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
