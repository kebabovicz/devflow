#!/bin/bash
# Regression suite for hooks/stop-gate.sh — the doctor layer-1 self-test cases,
# committed. Run via tests/run.sh or directly. Requires: bash, jq, git.
set -u

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/stop-gate.sh"
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

# A project mid-effort: a map with tickets, the repo excluding the map from git
# exactly as init sets it up, so a dirty tree can only mean uncommitted code.
PROJ="$SANDBOX/proj"
mkdir -p "$PROJ/.devflow/maps/billing/tickets"
git -C "$PROJ" init -q -b feature/x
printf 'maps:\n  dir: .devflow/maps\n' > "$PROJ/.devflow/project.yml"
printf '.devflow/maps/\n' > "$PROJ/.git/info/exclude"
printf 'Status: open\n' > "$PROJ/.devflow/maps/billing/tickets/01-schema.md"
git -C "$PROJ" add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm init

echo "stop-gate"
check 0 "$PROJ" false "clean tree allows stop"

# Work started but not committed, with no ticket claimed: the gate stays out of
# the way — an interactive session must be free to end mid-edit.
printf 'let x = 1\n' > "$PROJ/app.js"
check 0 "$PROJ" false "dirty tree alone does not block (no ticket in progress)"

# The same dirty tree once a ticket is in flight = an unfinished iteration.
printf 'Status: in progress\n' > "$PROJ/.devflow/maps/billing/tickets/01-schema.md"
check 2 "$PROJ" false "ticket in progress + dirty tree blocks stop"
check 0 "$PROJ" true  "stop_hook_active=true always allows (loop protection)"

git -C "$PROJ" add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm "01: schema"
check 0 "$PROJ" false "committed work allows stop even while the ticket is open"

# A ticket in progress with a clean tree is a fresh pick, not a failed iteration.
printf 'let y = 2\n' > "$PROJ/other.js"
printf 'Status: done\n' > "$PROJ/.devflow/maps/billing/tickets/01-schema.md"
check 0 "$PROJ" false "no ticket in progress => dirty tree allowed"

# The map itself is git-excluded, so ticket edits never read as a dirty tree.
git -C "$PROJ" add -A
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm other
printf 'Status: in progress\n' > "$PROJ/.devflow/maps/billing/tickets/01-schema.md"
check 0 "$PROJ" false "ticket edits are invisible to git, so they never trip the gate"

PLAIN="$SANDBOX/plain"; mkdir -p "$PLAIN"
check 0 "$PLAIN" false "no manifest => gate inactive"

NOMAP="$SANDBOX/nomap"; mkdir -p "$NOMAP/.devflow"
printf 'project:\n  name: x\n' > "$NOMAP/.devflow/project.yml"
check 0 "$NOMAP" false "no map directory => gate inactive"

# ── Parallel work: several efforts, several worktrees ───────────────────────
# The failure this covers, seen in the field: a repo with seven efforts and
# three worktrees blocked the WRONG session — a ticket in progress in effort A
# plus uncommitted files belonging to effort B satisfied both conditions.
PAR="$SANDBOX/parallel"
mkdir -p "$PAR/.devflow/maps/alpha/tickets" "$PAR/.devflow/maps/beta/tickets"
git -C "$PAR" init -q -b feature/alpha
printf 'maps:\n  dir: .devflow/maps\n' > "$PAR/.devflow/project.yml"
printf '.devflow/maps/\n' > "$PAR/.git/info/exclude"
printf '# alpha\n\nBranch: `feature/alpha`\n' > "$PAR/.devflow/maps/alpha/map.md"
printf '# beta\n\nBranch: `feature/beta`\n'   > "$PAR/.devflow/maps/beta/map.md"
printf 'Status: done\n'        > "$PAR/.devflow/maps/alpha/tickets/01-a.md"
printf 'Status: in progress\n' > "$PAR/.devflow/maps/beta/tickets/01-b.md"
git -C "$PAR" add -A
git -C "$PAR" -c user.email=t@t -c user.name=t commit -qm init
printf 'let x = 1\n' > "$PAR/app.js"

check 0 "$PAR" false "ticket in progress in another branch's effort does not block"

printf 'Status: in progress\n' > "$PAR/.devflow/maps/alpha/tickets/01-a.md"
check 2 "$PAR" false "ticket in progress in THIS branch's effort blocks"

# The interactive hand-over: work implemented, user reviewing before commit.
# task sets `awaiting review` when it presents the work — the gate must pass.
printf 'Status: awaiting review\n' > "$PAR/.devflow/maps/alpha/tickets/01-a.md"
check 0 "$PAR" false "awaiting review + dirty tree passes (user is reviewing, not a dead iteration)"
printf 'Status: in progress\n' > "$PAR/.devflow/maps/alpha/tickets/01-a.md"

# A worktree checks out tracked files only, so the map exists solely in the main
# tree. The gate must still find it — and must judge the worktree's own tree.
WT="$SANDBOX/parallel-beta"
git -C "$PAR" worktree add -q -b feature/beta-wt "$WT" 2>/dev/null
if [ -d "$WT" ]; then
  printf '# beta\n\nBranch: `feature/beta-wt`\n' > "$PAR/.devflow/maps/beta/map.md"
  check 0 "$WT" false "worktree with a clean tree allows stop (map read from the main tree)"
  printf 'let y = 2\n' > "$WT/wt.js"
  check 2 "$WT" false "worktree: its own dirty tree + its branch's ticket blocks"
  printf 'Status: done\n' > "$PAR/.devflow/maps/beta/tickets/01-b.md"
  check 0 "$WT" false "worktree: nothing in progress for its branch => allowed"
else
  printf '  skip worktree cases (git worktree unavailable)\n'
fi

echo
echo "stop-gate.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
