#!/usr/bin/env bash
# Human-in-the-loop reproduction script — for a bug that cannot be reproduced
# without a person: a real second factor, a physical device, a UI with no
# runner, an environment only their machine reaches.
#
# The agent copies this file OUTSIDE the project repository, edits the steps,
# and runs it; the person follows the prompts in their terminal. The point is
# that the run after the fix is the SAME run, not a similar conversation.
#
# Two helpers:
#   step "<instruction>"       show an instruction, wait for Enter
#   capture VAR "<question>"   ask a question, store the answer in VAR
#
# Everything captured is printed at the end as KEY=value, which the agent
# reads as data instead of parsing it out of a sentence.
#
# Rules that are not negotiable:
#   - only steps a person must do; anything the agent can run itself happens
#     before this script starts, so nobody watches machine steps in their terminal;
#   - no credentials anywhere in here — signing in is a `step` for the person,
#     never a value the script carries;
#   - delete the working copy during cleanup unless the user asked to keep it.

set -euo pipefail

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer
  printf -v "$var" '%s' "$answer"
}

# --- edit below ---------------------------------------------------------

step "Open the app at http://localhost:3000 and sign in."

capture ERRORED "Click Export. Did it fail? (y/n)"

capture ERROR_MSG "Paste the error message, or 'none':"

# --- edit above ---------------------------------------------------------

printf '\n--- Captured ---\n'
printf 'ERRORED=%s\n' "$ERRORED"
printf 'ERROR_MSG=%s\n' "$ERROR_MSG"
