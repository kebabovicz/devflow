#!/bin/bash
# devflow hook regression suite. Run from anywhere: tests/run.sh
# Exit 0 = all green. Requires: bash, jq, git.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$DIR"/*.test.sh; do
  echo "── $(basename "$t")"
  bash "$t" || rc=1
  echo
done
[ "$rc" -eq 0 ] && echo "ALL GREEN" || echo "FAILURES — see above"
exit "$rc"
