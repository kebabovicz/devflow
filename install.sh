#!/bin/bash
# devflow installer — idempotent. Run from anywhere after cloning the repo:
#   git clone <repo-url> ~/devflow && ~/devflow/install.sh
set -euo pipefail

DEVFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
LINK="$SKILLS_DIR/devflow"

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; }

echo "devflow installer"
echo "─────────────────"

# 1. Required dependencies
command -v claude >/dev/null 2>&1 && ok "claude CLI" || { fail "claude CLI not found — install Claude Code first: https://code.claude.com"; exit 1; }
command -v git    >/dev/null 2>&1 && ok "git"        || { fail "git not found"; exit 1; }
command -v jq     >/dev/null 2>&1 && ok "jq"         || warn "jq not found — guardrail hooks will be inactive (brew install jq)"
command -v docker >/dev/null 2>&1 && ok "docker"     || warn "docker not found — test-flow/Testcontainers won't work (install Docker Desktop)"

# 2. Hook scripts must be executable — a hook that exists but can't run surfaces
#    as a "Permission denied" error in EVERY session (Stop hooks fire globally).
chmod +x "$DEVFLOW_DIR"/hooks/*.sh 2>/dev/null && ok "hook scripts executable" || warn "could not chmod hook scripts — check $DEVFLOW_DIR/hooks"

# 3. Symlink into the skills directory (auto-loaded by Claude Code every session)
mkdir -p "$SKILLS_DIR"
if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$DEVFLOW_DIR" ]; then
  ok "plugin already linked: $LINK"
elif [ -e "$LINK" ]; then
  fail "$LINK exists and is not a link to this repo — resolve manually"; exit 1
else
  ln -s "$DEVFLOW_DIR" "$LINK"
  ok "plugin linked: $LINK -> $DEVFLOW_DIR"
fi

# 4. Optional extras
command -v claude-squad >/dev/null 2>&1 && ok "claude-squad (parallel sessions)" || warn "claude-squad not installed (optional): brew install tmux gh claude-squad"

echo
echo "Next steps:"
echo "  1. Start a new Claude Code session — skills appear as /devflow:* (check with /help)"
echo "  2. Jira integration (optional, once):"
echo "       claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp -s user"
echo "       then /mcp -> atlassian -> Authenticate"
echo "     Current library docs for /devflow:research (optional, once):"
echo "       claude mcp add --transport http context7 https://mcp.context7.com/mcp -s user"
echo "  3. Onboard a project: open a session in the project root and run /devflow:init"
echo "  4. Read the guide: $DEVFLOW_DIR/docs/GUIDE.md"
echo
echo "Update later with: git -C $DEVFLOW_DIR pull   (then /devflow:update in projects if the manifest template changed)"
