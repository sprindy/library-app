#!/usr/bin/env bash
set -euo pipefail
ROLE=${1:-}
if [[ -z "$ROLE" ]]; then
  echo "Usage: $0 <linus|leon|helen>"
  exit 1
fi
case "$ROLE" in
  linus|leon|helen) ;;
  *) echo "Invalid role: $ROLE"; exit 1;;
esac
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
CFG_BASE="$BASE/.gh-profiles"
REPO="$BASE/$ROLE/library-app"
export GH_CONFIG_DIR="$CFG_BASE/$ROLE"
cd "$REPO"
echo "Role: $ROLE"
echo "Repo: $REPO"
echo "GH_CONFIG_DIR: $GH_CONFIG_DIR"
echo "Git identity: $(git config user.name) <$(git config user.email)>"

echo
echo "Run these next if first time:"
echo "  gh auth login"
echo "  gh auth status"
echo
exec "$SHELL"
