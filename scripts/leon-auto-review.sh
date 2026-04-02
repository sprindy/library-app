#!/usr/bin/env bash
set -euo pipefail

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
RUN_DIR="$BASE/leon/runs"
WORKSPACES_DIR="$BASE/leon/workspaces"
export GH_CONFIG_DIR="$BASE/.gh-profiles/leon"
EXPECTED_LOGIN="LeonReviewer"
CRON_JOB_ID="${LEON_REVIEW_CRON_JOB_ID:-d366ae71-0fed-4578-a666-48a322063e0d}"
AUTO_DISABLE_ON_REVIEW_DONE="${LEON_AUTO_DISABLE_ON_REVIEW_DONE:-1}"

# Prevent shell-exported GH_TOKEN/GITHUB_TOKEN from overriding role profile auth.
unset GH_TOKEN
unset GITHUB_TOKEN

START_MARKER="[leon-review-started:v1]"
DONE_MARKER="[leon-review-submitted:v1]"

mkdir -p "$RUN_DIR" "$WORKSPACES_DIR"

disable_review_cron_if_configured() {
  local reason="$1"
  if [[ "$AUTO_DISABLE_ON_REVIEW_DONE" != "1" ]]; then
    return 0
  fi
  if [[ -z "$CRON_JOB_ID" ]]; then
    return 0
  fi
  if ! command -v openclaw >/dev/null 2>&1; then
    return 0
  fi

  if openclaw cron disable "$CRON_JOB_ID" >/dev/null 2>&1; then
    echo "disabled cron job $CRON_JOB_ID ($reason)"
  else
    echo "warning: failed to disable cron job $CRON_JOB_ID ($reason)" >&2
  fi
}

need_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found" >&2; exit 1; }
}
need_bin gh
need_bin codex
need_bin jq
need_bin git

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "ERROR: invalid GitHub auth for Leon profile (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
  exit 1
fi
gh auth switch -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
actual_login="$(gh api user --jq .login 2>/dev/null || true)"
if [[ "$actual_login" != "$EXPECTED_LOGIN" ]]; then
  echo "ERROR: authenticated as '$actual_login', expected '$EXPECTED_LOGIN' (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
  exit 1
fi

ISSUES=$(gh issue list \
  --repo "$REPO" \
  --state open \
  --label source:tester \
  --label role:reviewer-leon \
  --label status:in-review \
  --json number,title,url \
  --jq '.[] | @base64')

if [[ -z "${ISSUES}" ]]; then
  disable_review_cron_if_configured "no in-review issues assigned for Leon"
  exit 0
fi

acted=0
needs_review=0
while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  _jq() { echo "$row" | base64 --decode | jq -r "$1"; }

  num=$(_jq '.number')
  title=$(_jq '.title')

  pr_row=$(gh pr list --repo "$REPO" --state open --search "#${num}" --json number,title,url,headRefName --jq '.[0] | @base64')
  [[ -z "$pr_row" || "$pr_row" == "null" ]] && continue
  _pr() { echo "$pr_row" | base64 --decode | jq -r "$1"; }
  pr_number=$(_pr '.number')
  pr_url=$(_pr '.url')
  pr_branch=$(_pr '.headRefName')

  leon_reviews=$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="LeonReviewer")] | length')
  if [[ "$leon_reviews" != "0" ]]; then
    continue
  fi
  needs_review=1

  pid_file="$RUN_DIR/issue-${num}.pid"
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file" || true)"
    if [[ -n "${pid}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      continue
    fi
    rm -f "$pid_file"
  fi

  started_existing=$(gh issue view "$num" --repo "$REPO" --comments --json comments --jq '[.comments[] | select((.author.login=="LeonReviewer") and ((.body // "") | contains("[leon-review-started:v1]")))] | length')
  if [[ "$started_existing" == "0" ]]; then
    gh issue comment "$num" --repo "$REPO" --body "$START_MARKER Review automation started.

- PR: $pr_url
- Branch: \`$pr_branch\`
- Reviewer: \`LeonReviewer\`" >/dev/null
  fi

  ts=$(date +%Y%m%d-%H%M%S)
  log_file="$RUN_DIR/issue-${num}-${ts}.log"
  workdir="$WORKSPACES_DIR/issue-${num}-${ts}"

  prompt=$(cat <<EOF
You are Leon Reviewer working in repository $workdir.
Task: Review PR #$pr_number for issue #$num.
Issue title: $title
PR: $pr_url
Branch: $pr_branch

Requirements:
- Sync and check out the PR branch.
- Read ./SPEC.md and ./TASK_REVIEWER.md.
- Read ./app/HANDOFF_CODER.md if present.
- Perform a real review (correctness, risks, tests, edge cases).
- Run relevant checks/tests if available.
- Submit a PR review as LeonReviewer:
  - APPROVE if ready, otherwise REQUEST_CHANGES with clear blockers.
- Post an issue comment with marker $DONE_MARKER including verdict and next action.
- Keep scope focused on review work.
EOF
)

  (
    set -euo pipefail
    mkdir -p "$workdir"
    git clone --quiet "https://github.com/${REPO}.git" "$workdir"
    git -C "$workdir" fetch --quiet origin "$pr_branch"
    git -C "$workdir" checkout -B "$pr_branch" "origin/$pr_branch"

    # Run Codex without sandboxing so it can use git + gh normally.
    nohup codex exec --dangerously-bypass-approvals-and-sandbox -C "$workdir" "$prompt" >"$log_file" 2>&1 &
    echo $! > "$pid_file"
  )

  echo "started Leon review for issue #$num (PR #$pr_number, log: $log_file)"
  acted=1

done <<< "$ISSUES"

if [[ "$needs_review" == "0" ]]; then
  disable_review_cron_if_configured "all in-review issues already reviewed by Leon"
fi

[[ "$acted" == "1" ]] && exit 0
exit 0
