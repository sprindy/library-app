#!/usr/bin/env bash
set -euo pipefail

# Auto-route bridge for Linus:
# 1) ensure local branch kickoff for ANY open issue assigned to Linus
# 2) automatically start Codex implementation once per issue

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
LINUS_REPO="$BASE/linus/library-app"
RUN_DIR="$BASE/linus/runs"
STATE_DIR="$RUN_DIR/state"
export GH_CONFIG_DIR="$BASE/.gh-profiles/linus"
EXPECTED_LOGIN="CoderLinus"
CRON_JOB_ID="${LINUS_KICKOFF_CRON_JOB_ID:-a47cd449-b172-4c45-8649-7059a8202548}"
AUTO_DISABLE_ON_OPEN_PR="${LINUS_AUTO_DISABLE_ON_OPEN_PR:-1}"

# Prevent shell-exported GH_TOKEN/GITHUB_TOKEN from overriding role profile auth.
unset GH_TOKEN
unset GITHUB_TOKEN

KICKOFF_MARKER="[linus-local-started:v1]"
IMPL_MARKER="[linus-impl-started:v1]"

mkdir -p "$RUN_DIR" "$STATE_DIR"

disable_kickoff_cron_if_configured() {
  local reason="$1"
  if [[ "$AUTO_DISABLE_ON_OPEN_PR" != "1" ]]; then
    return 0
  fi
  if [[ -z "$CRON_JOB_ID" ]]; then
    return 0
  fi
  if ! command -v openclaw >/dev/null 2>&1; then
    return 0
  fi

  # Save token spend by disabling the polling job once all assigned issues already have PRs.
  if openclaw cron disable "$CRON_JOB_ID" >/dev/null 2>&1; then
    echo "disabled cron job $CRON_JOB_ID ($reason)"
  else
    echo "warning: failed to disable cron job $CRON_JOB_ID ($reason)" >&2
  fi
}

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh not found" >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex not found" >&2
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "ERROR: invalid GitHub auth for Linus profile (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
  exit 1
fi
gh auth switch -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
actual_login="$(gh api user --jq .login 2>/dev/null || true)"
if [[ "$actual_login" != "$EXPECTED_LOGIN" ]]; then
  echo "ERROR: authenticated as '$actual_login', expected '$EXPECTED_LOGIN' (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
  exit 1
fi

ISSUES=$(gh issue list --repo "$REPO" --state open --assignee CoderLinus --json number,title,url,labels --jq '.[] | @base64')
[[ -z "${ISSUES}" ]] && exit 0

acted=0
needs_impl=0
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
  needs_impl=1

  # Ensure workflow labels exist so routing/monitoring sees this issue.
  labels_csv=$(echo "$row" | base64 --decode | jq -r '[.labels[].name] | join(",")')
  if [[ "$labels_csv" != *"role:coder-linus"* ]] || [[ "$labels_csv" != *"status:in-dev"* ]]; then
    gh issue edit "$num" --repo "$REPO" --add-label role:coder-linus --add-label status:in-dev >/dev/null || true
  fi

  slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-36)
  branch="linus/issue-${num}-${slug}"
  pid_file="$RUN_DIR/issue-${num}.pid"
  marker_file="$STATE_DIR/issue-${num}.impl-started"

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
- Next: implementation starts automatically via Codex." >/dev/null || true
    echo "kicked off issue #$num on $branch"
    acted=1
  fi

  # If an implementation process is already running, do not start another.
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      continue
    fi
    rm -f "$pid_file"
  fi

  # Retry-safe cooldown:
  # If prior implementation was started but no PR is open and no process is alive,
  # allow retries after cooldown instead of blocking forever on comment marker.
  impl_existing=$(gh issue view "$num" --repo "$REPO" --comments --json comments --jq '[.comments[] | select((.author.login=="CoderLinus") and ((.body // "") | contains("[linus-impl-started:v1]")))] | length')
  now_epoch="$(date +%s)"
  cooldown_ref=0
  if [[ -f "$marker_file" ]]; then
    cooldown_ref="$(stat -f %m "$marker_file" 2>/dev/null || echo 0)"
  elif [[ "$impl_existing" != "0" ]]; then
    latest_log="$(ls -t "$RUN_DIR/issue-${num}-"*.log 2>/dev/null | head -n 1 || true)"
    if [[ -n "$latest_log" ]]; then
      cooldown_ref="$(stat -f %m "$latest_log" 2>/dev/null || echo 0)"
    fi
  fi
  if (( cooldown_ref > 0 && now_epoch - cooldown_ref < 900 )); then
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
- If the workspace already has local uncommitted edits related to this issue, continue and include them; do not pause for confirmation.
EOF
)

  (
    cd "$LINUS_REPO"
    # Run Codex without sandboxing so it can use git + gh normally.
    nohup codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.3-codex "$prompt" >"$log_file" 2>&1 &
    echo $! > "$pid_file"
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$marker_file"
  )

  gh issue comment "$num" --repo "$REPO" --body "$IMPL_MARKER Codex implementation started.

- Branch: \`$branch\`
- Log: \`$log_file\`
- Next: push + PR creation with \`Fixes #$num\`." >/dev/null || true

  echo "started implementation for issue #$num (log: $log_file)"
  acted=1
done <<< "$ISSUES"

if [[ "$needs_impl" == "0" ]]; then
  disable_kickoff_cron_if_configured "all assigned open issues already have open PRs"
fi

[[ "$acted" == "1" ]] && exit 0
exit 0
