#!/bin/bash
# Regression suite for hooks/guard.sh — the cases from the 0.12.0/0.18.1
# adversarial reviews plus the 0.20.0 push/merge guards. Run via tests/run.sh
# or directly. Requires: bash, jq, git.
set -u

GUARD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/guard.sh"
PASS=0 FAIL=0

# Sandboxes (never the real project): a devflow project on the base branch,
# one on a feature branch, and a plain non-devflow dir.
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mk_repo() { # $1=dir $2=branch
  mkdir -p "$1/.devflow"
  git -C "$1" init -q -b "$2"
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf 'git:\n  base_branch: main\n' > "$1/.devflow/project.yml"
}
ON_MAIN="$SANDBOX/on-main";    mk_repo "$ON_MAIN" main
ON_FEAT="$SANDBOX/on-feature"; mk_repo "$ON_FEAT" main
git -C "$ON_FEAT" checkout -q -b feature/x
PLAIN="$SANDBOX/plain"; mkdir -p "$PLAIN"

check() { # $1=expected-exit $2=cwd $3=description $4=command
  local out rc
  out=$(printf '{"tool_input":{"command":%s},"cwd":%s}' \
        "$(printf '%s' "$4" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" \
        | "$GUARD" 2>&1); rc=$?
  if [ "$rc" -eq "$1" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$3"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s (expected exit %s, got %s)\n       cmd: %s\n       out: %s\n' "$3" "$1" "$rc" "$4" "$out"
  fi
}

# Dangerous docker strings are assembled at runtime (doctor's 0.5.1 trick) so
# this file itself never contains a blockable literal.
V="vol""ume"; DOWNV="down -""v"; PRUNE="pr""une"

echo "guard: volume protection"
check 2 "$ON_FEAT" "compose down -v blocked"            "docker compose $DOWNV"
check 2 "$ON_FEAT" "compose down --volumes blocked"     "docker compose down --$V""s"
check 2 "$ON_FEAT" "docker-compose (V1) down -v blocked" "docker-compose $DOWNV"
check 2 "$ON_FEAT" "compose rm flag-cluster -sfv blocked" "docker compose rm -sf""v api"
check 2 "$ON_FEAT" "volume rm blocked"                  "docker $V rm mydata"
check 2 "$ON_FEAT" "volume prune blocked"               "docker $V $PRUNE"
check 2 "$ON_FEAT" "system prune --volumes blocked"     "docker system $PRUNE --$V""s"
check 0 "$ON_FEAT" "plain compose down allowed"         "docker compose down"
check 0 "$ON_FEAT" "compose up allowed"                 "docker compose up -d --build"
check 2 "$ON_FEAT" "dangerous literal in echo arg blocks (fail-safe by design)" "echo \"docker $V $PRUNE\""
check 0 "$ON_FEAT" "DEVFLOW_ALLOW=1 bypasses"           "DEVFLOW_ALLOW=1 docker $V $PRUNE"
check 0 "$ON_FEAT" "bypass with leading whitespace"     "  DEVFLOW_ALLOW=1 docker compose $DOWNV"
check 2 "$ON_FEAT" "bypass string not at start does NOT disarm" "echo DEVFLOW_ALLOW=1 && docker $V $PRUNE"
check 0 "$PLAIN"   "no manifest => guard inactive"      "docker $V $PRUNE"

echo "guard: base-branch commits"
check 2 "$ON_MAIN" "commit on base blocked"             "git commit -m x"
check 0 "$ON_FEAT" "commit on feature allowed"          "git commit -m x"
check 2 "$ON_MAIN" "git -c opt commit on base blocked"  "git -c user.name=x commit -m x"
check 2 "$ON_MAIN" "VAR=val git commit on base blocked" "GIT_AUTHOR_NAME=x git commit -m x"
check 2 "$ON_FEAT" "git -C <base-repo> commit blocked from elsewhere" "git -C $ON_MAIN commit -m x"
check 0 "$ON_MAIN" "'git commit' inside quoted arg allowed" "echo \"git commit\""

echo "guard: base-branch pushes"
check 2 "$ON_FEAT" "push origin base blocked"           "git push origin main"
check 2 "$ON_FEAT" "push -u origin base blocked"        "git push -u origin main"
check 2 "$ON_FEAT" "push HEAD:base blocked"             "git push origin HEAD:main"
check 2 "$ON_FEAT" "push feature:base blocked"          "git push origin feature/x:main"
check 2 "$ON_FEAT" "push :base (delete) blocked"        "git push origin :main"
check 2 "$ON_FEAT" "push --delete base blocked"         "git push origin --delete main"
check 0 "$ON_FEAT" "push feature branch allowed"        "git push -u origin feature/x"
check 0 "$ON_FEAT" "push branch with base prefix allowed" "git push origin mainline"
check 2 "$ON_MAIN" "bare push while on base blocked"    "git push"
check 0 "$ON_FEAT" "bare push on feature allowed"       "git push"

echo "guard: merges into base"
check 2 "$ON_MAIN" "merge while on base blocked"        "git merge feature/x"
check 0 "$ON_FEAT" "merge base into feature allowed"    "git merge main"
check 2 "$ON_MAIN" "cherry-pick while on base blocked"  "git cherry-pick abc123"
check 0 "$ON_MAIN" "pull on base allowed (sanctioned base update)" "git pull"

echo
echo "guard.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
