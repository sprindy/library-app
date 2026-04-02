#!/usr/bin/env bash
set -euo pipefail

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
HELEN_REPO="$BASE/helen/library-app"
LINUS_REPO="$BASE/linus/library-app"
LEON_REPO="$BASE/leon/library-app"
RUN_DIR="$BASE/helen/runs"
STATE_DIR="$RUN_DIR/state"
export GH_CONFIG_DIR="$BASE/.gh-profiles/helen"
EXPECTED_LOGIN="TesterHelen"
CRON_JOB_ID="${HELEN_TEST_CRON_JOB_ID:-d33e2e65-c67d-4194-986c-e9dbb3c417dd}"
AUTO_DISABLE_ON_QA_DONE="${HELEN_AUTO_DISABLE_ON_QA_DONE:-1}"
AUTO_AUTH_HEAL="${HELEN_AUTO_AUTH_HEAL:-1}"
CODEX_TIMEOUT_SECONDS="${HELEN_CODEX_TIMEOUT_SECONDS:-1800}"
RETRY_COOLDOWN_SECONDS="${HELEN_RETRY_COOLDOWN_SECONDS:-900}"

# Prevent shell-exported GH_TOKEN/GITHUB_TOKEN from overriding role profile auth.
unset GH_TOKEN
unset GITHUB_TOKEN

START_MARKER="[helen-test-started:v1]"
DONE_MARKER="[helen-test-submitted:v1]"
FAIL_MARKER="[helen-test-failed:v1]"

mkdir -p "$RUN_DIR" "$STATE_DIR"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: $1 not found" >&2
    exit 1
  }
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
  local pat="${TESTER_PAT:-}"

  if ! gh auth status -h github.com >/dev/null 2>&1; then
    if [[ "$AUTO_AUTH_HEAL" == "1" && -n "$pat" ]]; then
      gh auth logout -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
      printf '%s' "$pat" | gh auth login -h github.com --with-token -p https >/dev/null
    else
      echo "ERROR: invalid GitHub auth for Helen profile (GH_CONFIG_DIR=$GH_CONFIG_DIR). Export TESTER_PAT to auto-heal." >&2
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

disable_test_cron_if_configured() {
  local reason="$1"
  if [[ "$AUTO_DISABLE_ON_QA_DONE" != "1" ]]; then
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

need_bin gh
need_bin codex
need_bin jq
need_bin git
if [[ ! -d "$HELEN_REPO/.git" ]]; then
  echo "ERROR: Helen repo workspace not found: $HELEN_REPO" >&2
  exit 1
fi

ensure_role_auth

cleanup_local_temp_branches() {
  local pr_branch="$1"
  local pr_number="$2"
  local repo current

  for repo in "$LINUS_REPO" "$LEON_REPO" "$HELEN_REPO"; do
    [[ -d "$repo/.git" ]] || continue
    current="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ "$current" == "$pr_branch" || "$current" == "pr-$pr_number" ]]; then
      git -C "$repo" checkout main >/dev/null 2>&1 || true
    fi
    git -C "$repo" branch -D "$pr_branch" >/dev/null 2>&1 || true
    git -C "$repo" branch -D "pr-$pr_number" >/dev/null 2>&1 || true
  done
}

finalize_if_ready() {
  local num="$1"
  local pr_number="$2"
  local pr_branch="$3"
  local pr_state leon_state helen_state

  pr_state="$(gh pr view "$pr_number" --repo "$REPO" --json state --jq '.state' 2>/dev/null || true)"
  [[ "$pr_state" == "OPEN" ]] || return 1

  leon_state="$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="LeonReviewer")][-1].state // ""' 2>/dev/null || true)"
  helen_state="$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="TesterHelen")][-1].state // ""' 2>/dev/null || true)"
  [[ "$leon_state" == "APPROVED" && "$helen_state" == "APPROVED" ]] || return 1

  # Finalization actions for every completed QA cycle:
  # 1) assign Linus, 2) merge PR, 3) close issue, 4) delete temp branches.
  gh issue edit "$num" --repo "$REPO" --add-assignee CoderLinus >/dev/null || true
  gh pr edit "$pr_number" --repo "$REPO" --add-assignee CoderLinus >/dev/null || true

  if gh pr merge "$pr_number" --repo "$REPO" --merge --delete-branch >/dev/null 2>&1; then
    gh issue close "$num" --repo "$REPO" --reason completed >/dev/null 2>&1 || true
    cleanup_local_temp_branches "$pr_branch" "$pr_number"
    echo "finalized issue #$num (merged PR #$pr_number, assigned Linus, closed issue, cleaned temp branches)"
    return 0
  fi

  return 1
}

ISSUES=$(gh issue list \
  --repo "$REPO" \
  --state open \
  --label source:tester \
  --label role:tester-helen \
  --label status:qa \
  --json number,title,url \
  --jq '.[] | @base64')

if [[ -z "${ISSUES}" ]]; then
  disable_test_cron_if_configured "no QA issues for Helen"
  exit 0
fi

acted=0
needs_test=0
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

  if finalize_if_ready "$num" "$pr_number" "$pr_branch"; then
    acted=1
    continue
  fi

  helen_reviews=$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="TesterHelen")] | length')
  if [[ "$helen_reviews" != "0" ]]; then
    continue
  fi
  needs_test=1

  pid_file="$RUN_DIR/issue-${num}.pid"
  marker_file="$STATE_DIR/issue-${num}.test-started"
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

  started_existing=$(gh issue view "$num" --repo "$REPO" --comments --json comments --jq '[.comments[] | select((.author.login=="TesterHelen") and ((.body // "") | contains("[helen-test-started:v1]")))] | length')
  if [[ "$started_existing" == "0" ]]; then
    gh issue comment "$num" --repo "$REPO" --body "$START_MARKER QA automation started.

- PR: $pr_url
- Branch: \`$pr_branch\`
- Tester: \`TesterHelen\`" >/dev/null
  fi

  ts=$(date +%Y%m%d-%H%M%S)
  log_file="$RUN_DIR/issue-${num}-${ts}.log"

  prompt=$(cat <<EOF
You are Helen Tester working in repository $HELEN_REPO.
Task: Test PR #$pr_number for issue #$num.
Issue title: $title
PR: $pr_url
Branch: $pr_branch

Requirements:
- Sync and check out the PR branch.
- Read ./SPEC.md and ./TASK_TESTER.md.
- Read ./app/REVIEW_REPORT.md if present.
- Execute practical validation and run relevant checks/tests where available.
- Update test artifacts if needed (TEST_PLAN.md, BUG_REPORT.md, TEST_SIGNOFF.md).
- Submit a PR review as TesterHelen:
  - APPROVE if QA passes, otherwise REQUEST_CHANGES with reproducible defects.
- Post an issue comment with marker $DONE_MARKER including verdict and open bug summary.
- Keep scope focused on testing/validation.
- If the workspace already has local uncommitted QA artifacts, continue and include them; do not pause for confirmation.
EOF
)

  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$marker_file"
  echo "$$" > "$pid_file"
  codex_rc=0
  # Run foreground for reliability: background nohup launches can crash under launchd.
  run_with_timeout "$CODEX_TIMEOUT_SECONDS" \
    codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.3-codex -C "$HELEN_REPO" "$prompt" \
    >"$log_file" 2>&1 || codex_rc=$?
  rm -f "$pid_file"

  # Fallback path: if Codex did not submit a review, run deterministic QA checks and submit.
  post_helen_reviews=$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="TesterHelen")] | length')
  if [[ "$post_helen_reviews" == "0" ]]; then
    smoke_log="$RUN_DIR/issue-${num}-${ts}.smoke.log"
    qa_branch="qa-pr-${pr_number}"
    if (
      cd "$HELEN_REPO"
      git fetch --quiet origin "$pr_branch"
      git checkout -B "$qa_branch" "origin/$pr_branch"
      cd app
      swift test
    ) >"$smoke_log" 2>&1; then
      gh pr review "$pr_number" --repo "$REPO" --approve --body "Helen QA approved after deterministic smoke validation (swift test pass)." >/dev/null || true
      printf "%s\n" \
        "$DONE_MARKER QA completed." \
        "" \
        "- Verdict: APPROVED" \
        "- PR: $pr_url" \
        "- Open bugs: none found in this validation pass." \
        "- Validation: swift test (log: \`$smoke_log\`)" \
        | gh issue comment "$num" --repo "$REPO" --body-file - >/dev/null || true
    else
      gh pr review "$pr_number" --repo "$REPO" --request-changes --body "Helen QA found reproducible failures in deterministic smoke validation. See log: $smoke_log" >/dev/null || true
      printf "%s\n" \
        "$DONE_MARKER QA completed." \
        "" \
        "- Verdict: REQUEST_CHANGES" \
        "- PR: $pr_url" \
        "- Open bugs: smoke validation failed; see log \`$smoke_log\`." \
        | gh issue comment "$num" --repo "$REPO" --body-file - >/dev/null || true
    fi
  fi

  post_helen_reviews=$(gh pr view "$pr_number" --repo "$REPO" --json reviews --jq '[.reviews[] | select(.author.login=="TesterHelen")] | length')
  if [[ "$post_helen_reviews" == "0" ]]; then
    if [[ "$codex_rc" -eq 124 ]]; then
      fail_reason="timed out after ${CODEX_TIMEOUT_SECONDS}s and fallback did not submit review"
    elif [[ "$codex_rc" -ne 0 ]]; then
      fail_reason="exited with code ${codex_rc} and fallback did not submit review"
    else
      fail_reason="completed without submitting a review"
    fi
    gh issue comment "$num" --repo "$REPO" --body "$FAIL_MARKER QA attempt did not submit a PR review.

- PR: $pr_url
- Result: $fail_reason
- Log: \`$log_file\`
- Next: retry after cooldown (\`${RETRY_COOLDOWN_SECONDS}s\`)." >/dev/null || true
    echo "warning: issue #$num QA attempt failed ($fail_reason, log: $log_file)" >&2
  fi

  if finalize_if_ready "$num" "$pr_number" "$pr_branch"; then
    acted=1
    continue
  fi

  echo "completed Helen QA run for issue #$num (PR #$pr_number, log: $log_file)"
  acted=1
done <<< "$ISSUES"

if [[ "$needs_test" == "0" ]]; then
  disable_test_cron_if_configured "all QA issues already reviewed by Helen"
fi

[[ "$acted" == "1" ]] && exit 0
exit 0
