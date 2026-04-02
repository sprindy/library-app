#!/usr/bin/env bash
set -euo pipefail

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
RUN_DIR="$BASE/leon/runs"
STATE_DIR="$RUN_DIR/state"
WORKSPACES_DIR="$BASE/leon/workspaces"
export GH_CONFIG_DIR="$BASE/.gh-profiles/leon"
EXPECTED_LOGIN="LeonReviewer"
CRON_JOB_ID="${LEON_REVIEW_CRON_JOB_ID:-d366ae71-0fed-4578-a666-48a322063e0d}"
AUTO_DISABLE_ON_REVIEW_DONE="${LEON_AUTO_DISABLE_ON_REVIEW_DONE:-1}"
AUTO_AUTH_HEAL="${LEON_AUTO_AUTH_HEAL:-1}"
CODEX_TIMEOUT_SECONDS="${LEON_CODEX_TIMEOUT_SECONDS:-1800}"
RETRY_COOLDOWN_SECONDS="${LEON_RETRY_COOLDOWN_SECONDS:-900}"

# Prevent shell-exported GH_TOKEN/GITHUB_TOKEN from overriding role profile auth.
unset GH_TOKEN
unset GITHUB_TOKEN

START_MARKER="[leon-review-started:v1]"
DONE_MARKER="[leon-review-submitted:v1]"
FAIL_MARKER="[leon-review-failed:v1]"

mkdir -p "$RUN_DIR" "$STATE_DIR" "$WORKSPACES_DIR"

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

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  if [[ "$timeout_seconds" -le 0 ]]; then
    "$@"
    return $?
  fi

  "$@" &
  local cmd_pid=$!

  (
    sleep "$timeout_seconds"
    if kill -0 "$cmd_pid" >/dev/null 2>&1; then
      kill -TERM "$cmd_pid" >/dev/null 2>&1 || true
      sleep 5
      kill -KILL "$cmd_pid" >/dev/null 2>&1 || true
    fi
  ) &
  local guard_pid=$!

  local rc=0
  wait "$cmd_pid" || rc=$?
  kill "$guard_pid" >/dev/null 2>&1 || true
  wait "$guard_pid" >/dev/null 2>&1 || true
  if [[ "$rc" -eq 143 || "$rc" -eq 137 ]]; then
    return 124
  fi
  return "$rc"
}

ensure_role_auth() {
  local pat="${REVIEWER_PAT:-}"

  if ! gh auth status -h github.com >/dev/null 2>&1; then
    if [[ "$AUTO_AUTH_HEAL" == "1" && -n "$pat" ]]; then
      gh auth logout -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
      printf '%s' "$pat" | gh auth login -h github.com --with-token -p https >/dev/null
    else
      echo "ERROR: invalid GitHub auth for Leon profile (GH_CONFIG_DIR=$GH_CONFIG_DIR). Export REVIEWER_PAT to auto-heal." >&2
      exit 1
    fi
  fi

  gh auth switch -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
  local actual_login
  actual_login="$(gh api user --jq .login 2>/dev/null || true)"
  if [[ "$actual_login" == "$EXPECTED_LOGIN" ]]; then
    return 0
  fi

  if [[ "$AUTO_AUTH_HEAL" == "1" && -n "$pat" ]]; then
    gh auth logout -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
    printf '%s' "$pat" | gh auth login -h github.com --with-token -p https >/dev/null
    gh auth switch -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
    actual_login="$(gh api user --jq .login 2>/dev/null || true)"
  fi

  if [[ "$actual_login" != "$EXPECTED_LOGIN" ]]; then
    echo "ERROR: authenticated as '$actual_login', expected '$EXPECTED_LOGIN' (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
    exit 1
  fi
}

need_bin gh
need_bin codex
need_bin jq
need_bin git
ensure_role_auth

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
  marker_file="$STATE_DIR/issue-${num}.review-started"

  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file" || true)"
    if [[ -n "${pid}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      continue
    fi
    rm -f "$pid_file"
  fi

  now_epoch="$(date +%s)"
  cooldown_ref=0
  if [[ -f "$marker_file" ]]; then
    cooldown_ref="$(stat -f %m "$marker_file" 2>/dev/null || echo 0)"
  fi
  if (( cooldown_ref > 0 && now_epoch - cooldown_ref < RETRY_COOLDOWN_SECONDS )); then
    continue
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
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$marker_file"

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

  echo "$$" > "$pid_file"
  review_rc=0
  (
    set -euo pipefail
    mkdir -p "$workdir"
    git clone --quiet "https://github.com/${REPO}.git" "$workdir"
    git -C "$workdir" fetch --quiet origin "$pr_branch"
    git -C "$workdir" checkout -B "$pr_branch" "origin/$pr_branch"

    # Foreground execution is more reliable under launchd than detached nohup jobs.
    run_with_timeout "$CODEX_TIMEOUT_SECONDS" \
      codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.3-codex -C "$workdir" "$prompt"
  ) >"$log_file" 2>&1 || review_rc=$?
  rm -f "$pid_file"

  # Fallback path: if Codex did not submit a review, run deterministic checks and submit.
  post_reviews=$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="LeonReviewer")] | length')
  if [[ "$post_reviews" == "0" ]]; then
    smoke_log="$RUN_DIR/issue-${num}-${ts}.smoke.log"
    if (
      cd "$workdir/app"
      swift test
    ) >"$smoke_log" 2>&1; then
      gh pr review "$pr_number" --repo "$REPO" --approve --body "Leon review approved after deterministic validation (swift test pass)." >/dev/null || true
      gh issue edit "$num" --repo "$REPO" --remove-label status:in-review --add-label status:qa >/dev/null || true
      printf "%s\n" \
        "$DONE_MARKER Review completed." \
        "" \
        "- Verdict: APPROVED" \
        "- PR: $pr_url" \
        "- Validation: swift test (log: \`$smoke_log\`)" \
        "- Next: moved issue to \`status:qa\` for Helen testing." \
        | gh issue comment "$num" --repo "$REPO" --body-file - >/dev/null || true
    else
      gh pr review "$pr_number" --repo "$REPO" --request-changes --body "Leon review found issues in deterministic validation. See log: $smoke_log" >/dev/null || true
      gh issue edit "$num" --repo "$REPO" --remove-label status:in-review --add-label status:in-dev >/dev/null || true
      printf "%s\n" \
        "$DONE_MARKER Review completed." \
        "" \
        "- Verdict: REQUEST_CHANGES" \
        "- PR: $pr_url" \
        "- Validation: swift test failed (log: \`$smoke_log\`)" \
        "- Next: moved issue to \`status:in-dev\` for coder follow-up." \
        | gh issue comment "$num" --repo "$REPO" --body-file - >/dev/null || true
    fi
  fi

  post_reviews=$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="LeonReviewer")] | length')
  if [[ "$post_reviews" != "0" ]]; then
    echo "completed Leon review for issue #$num (PR #$pr_number, log: $log_file)"
    acted=1
    continue
  fi

  if [[ "$review_rc" -eq 124 ]]; then
    fail_reason="timed out after ${CODEX_TIMEOUT_SECONDS}s"
  elif [[ "$review_rc" -ne 0 ]]; then
    fail_reason="exited with code ${review_rc}"
  else
    fail_reason="completed without submitting a PR review"
  fi

  gh issue comment "$num" --repo "$REPO" --body "$FAIL_MARKER Review attempt did not submit a PR review.

- PR: $pr_url
- Result: $fail_reason
- Log: \`$log_file\`
- Next: retry after cooldown (\`${RETRY_COOLDOWN_SECONDS}s\`)." >/dev/null || true
  echo "warning: issue #$num review attempt failed ($fail_reason, log: $log_file)" >&2
  acted=1

done <<< "$ISSUES"

if [[ "$needs_review" == "0" ]]; then
  disable_review_cron_if_configured "all in-review issues already reviewed by Leon"
fi

[[ "$acted" == "1" ]] && exit 0
exit 0
