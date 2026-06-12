#!/bin/bash
# devflow init reminder — deterministic nudge for an unfinished onboarding.
#
# /devflow:init tracks its progress in .devflow/INIT.md and deletes the file
# only when every step is done (or explicitly deferred). If the file survives
# into a new session, the init was abandoned midway — the most common way a
# project ends up half-configured, because nothing else ever surfaces it.
# This hook puts one line into the session context so both the user and the
# agent start the session knowing there is unfinished setup.
#
# Design rules (same as guard.sh / ralph-stop-gate.sh):
#   * FAIL-OPEN: any parsing/tooling problem => exit 0 (stay silent).
#   * Scoped: only fires when the session cwd contains .devflow/INIT.md.
#   * Never blocks: SessionStart stdout is informational context, exit 0 always.
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && exit 0
[ -f "$cwd/.devflow/INIT.md" ] || exit 0

echo "devflow: onboarding of this project is UNFINISHED — .devflow/INIT.md has pending steps. Resume with /devflow:init (it continues from the first unchecked step). Until init completes, manifest-driven commands may work with unverified or missing configuration."
exit 0
