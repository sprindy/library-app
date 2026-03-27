#!/usr/bin/env bash
set -euo pipefail

BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"

usage() {
  cat <<EOF
Usage: $0 <linus|leon|helen>

Switches into the selected agent workspace and shows identity/auth status hints.
EOF
}

ROLE="${1:-}"
if [[ -z "$ROLE" ]]; then
  usage
  exit 1
fi

case "$ROLE" in
  linus|leon|helen) ;;
  *)
    usage
    exit 1
    ;;
esac

REPO_DIR="$BASE/$ROLE/library-app"
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "Workspace not found: $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

echo "Role: $ROLE"
echo "Repo: $REPO_DIR"
echo "Git identity: $(git config user.name) <$(git config user.email)>"

echo
if gh auth status >/dev/null 2>&1; then
  echo "gh auth: logged in"
  gh auth status || true
else
  echo "gh auth: not logged in (run: gh auth login)"
fi

echo
echo "Common commands:"
echo "  git fetch upstream && git checkout main && git pull --ff-only upstream main"
echo "  git checkout -b ${ROLE}/issue-<id>-<slug>"
echo "  # work, commit, push"
echo "  gh pr create --base main --title 'fix: ... (#<id>)' --body 'Fixes #<id>'"
