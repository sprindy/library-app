#!/usr/bin/env bash
set -euo pipefail

# Auto-route bridge for Linus:
# 1) ensure local branch kickoff for tester-flow in-dev issues
# 2) automatically start Codex implementation once per issue

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
LINUS_REPO="$BASE/linus/library-app"
RUN_DIR="$BASE/linus/runs"
export GH_CONFIG_DIR="$BASE/.gh-profiles/linus"

KICKOFF_MARKER="[linus-local-started:v1]"
IMPL_MARKER="[linus-impl-started:v1]"

mkdir -p "$RUN_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh not found" >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex not found" >&2
  exit 1
fi

ISSUES=$(gh issue list --repo "$REPO" --state open --assignee CoderLinus --label source:tester --label status:in-dev --json number,title,url --jq '.[] | @base64')
[[ -z "${ISSUES}" ]] && exit 0

acted=0
while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  _jq() { echo "$row" | base64 --decode | jq -r "$1"; }

  num=$(_jq '.number')
  title=$(_jq '.title')

  # Skip when PR already exists
  linked_prs=$(gh pr list --repo "$REPO" --state open --search "#${num}" --json number --jq 'length')
  if [[ "$linked_prs" != "0" ]]; then
    continue
  fi

  slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-36)
  branch="linus/issue-${num}-${slug}"

  # Prepare local branch in Linus clone
  git -C "$LINUS_REPO" fetch upstream main || true
  git -C "$LINUS_REPO" checkout main
  git -C "$LINUS_REPO" pull --ff-only upstream main || true
  if git -C "$LINUS_REPO" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$LINUS_REPO" checkout "$branch"
  else
    git -C "$LINUS_REPO" checkout -b "$branch"
  fi

  # Kickoff comment (idempotent)
  kickoff_existing=$(gh issue view "$num" --repo "$REPO" --comments --json comments --jq '[.comments[] | select((.author.login=="CoderLinus") and ((.body // "") | contains("[linus-local-started:v1]")))] | length')
  if [[ "$kickoff_existing" == "0" ]]; then
    gh issue comment "$num" --repo "$REPO" --body "$KICKOFF_MARKER Picked up for implementation locally.

- Branch: \`$branch\`
- Workspace: \`$LINUS_REPO\`
- Next: implementation starts automatically via Codex." >/dev/null
    echo "kicked off issue #$num on $branch"
    acted=1
  fi

  # Start implementation once (idempotent marker)
  impl_existing=$(gh issue view "$num" --repo "$REPO" --comments --json comments --jq '[.comments[] | select((.author.login=="CoderLinus") and ((.body // "") | contains("[linus-impl-started:v1]")))] | length')
  if [[ "$impl_existing" != "0" ]]; then
    continue
  fi

  ts=$(date +%Y%m%d-%H%M%S)
  log_file="$RUN_DIR/issue-${num}-${ts}.log"

  prompt=$(cat <<EOF
You are Linus Coder working in repository $LINUS_REPO.
Task: Fix issue #$num.
Issue title: $title

Requirements:
- Implement a real fix for the issue.
- Run relevant tests/build checks if available.
- Commit with your git identity configured in this repo.
- Push branch: $branch
- Open a PR to main in $REPO with:
  - title starting with: fix:
  - body containing: Fixes #$num
  - request reviewers: LeonReviewer and TesterHelen
- Keep changes focused only on this issue.
EOF
)

  (
    cd "$LINUS_REPO"
    nohup codex exec --full-auto "$prompt" >"$log_file" 2>&1 &
    echo $! > "$RUN_DIR/issue-${num}.pid"
  )

  gh issue comment "$num" --repo "$REPO" --body "$IMPL_MARKER Codex implementation started.

- Branch: \`$branch\`
- Log: \`$log_file\`
- Next: push + PR creation with \`Fixes #$num\`." >/dev/null

  echo "started implementation for issue #$num (log: $log_file)"
  acted=1
done <<< "$ISSUES"

[[ "$acted" == "1" ]] && exit 0
exit 0
