#!/usr/bin/env bash
set -euo pipefail

# Auto-kickoff bridge: when tester-flow issues are in-dev and assigned to CoderLinus,
# create a local branch in Linus workspace and post a "started" comment once.

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
LINUS_REPO="$BASE/linus/library-app"
export GH_CONFIG_DIR="$BASE/.gh-profiles/linus"
MARKER="[linus-local-started:v1]"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh not found" >&2
  exit 1
fi

# Find candidate issues
ISSUES=$(gh issue list --repo "$REPO" --state open --assignee CoderLinus --label source:tester --label status:in-dev --json number,title,url --jq '.[] | @base64')

if [[ -z "${ISSUES}" ]]; then
  exit 0
fi

acted=0
while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  _jq() { echo "$row" | base64 --decode | jq -r "$1"; }

  num=$(_jq '.number')
  title=$(_jq '.title')

  # Skip if Linus already posted kickoff marker
  existing=$(gh issue view "$num" --repo "$REPO" --comments --json comments --jq '[.comments[] | select((.author.login=="CoderLinus") and ((.body // "") | contains("[linus-local-started:v1]")))] | length')
  if [[ "$existing" != "0" ]]; then
    continue
  fi

  # Skip if there is already an open PR linked to this issue
  linked_prs=$(gh pr list --repo "$REPO" --state open --search "#${num}" --json number --jq 'length')
  if [[ "$linked_prs" != "0" ]]; then
    continue
  fi

  slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-36)
  branch="linus/issue-${num}-${slug}"

  # Prepare local branch in Linus clone
  git -C "$LINUS_REPO" fetch upstream main
  git -C "$LINUS_REPO" checkout main
  git -C "$LINUS_REPO" pull --ff-only upstream main
  if git -C "$LINUS_REPO" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$LINUS_REPO" checkout "$branch"
  else
    git -C "$LINUS_REPO" checkout -b "$branch"
  fi

  gh issue comment "$num" --repo "$REPO" --body "$MARKER Picked up for implementation locally.\n\n- Branch: \\`$branch\\`\n- Workspace: \\`$LINUS_REPO\\`\n- Next: implement fix and open PR with \\`Fixes #$num\\`."

  echo "kicked off issue #$num on $branch"
  acted=1
done <<< "$ISSUES"

# Print only when action happened (good for cron noise control)
if [[ "$acted" == "1" ]]; then
  exit 0
fi
