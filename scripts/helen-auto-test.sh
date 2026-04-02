#!/usr/bin/env bash
set -euo pipefail

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
HELEN_REPO="$BASE/helen/library-app"
LINUS_REPO="$BASE/linus/library-app"
LEON_REPO="$BASE/leon/library-app"
RUN_DIR="$BASE/helen/runs"
export GH_CONFIG_DIR="$BASE/.gh-profiles/helen"
EXPECTED_LOGIN="TesterHelen"
CRON_JOB_ID="${HELEN_TEST_CRON_JOB_ID:-d33e2e65-c67d-4194-986c-e9dbb3c417dd}"
AUTO_DISABLE_ON_QA_DONE="${HELEN_AUTO_DISABLE_ON_QA_DONE:-1}"

# Prevent shell-exported GH_TOKEN/GITHUB_TOKEN from overriding role profile auth.
unset GH_TOKEN
unset GITHUB_TOKEN

START_MARKER="[helen-test-started:v1]"
DONE_MARKER="[helen-test-submitted:v1]"

mkdir -p "$RUN_DIR"

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

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh not found" >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex not found" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found" >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found" >&2
  exit 1
fi
if [[ ! -d "$HELEN_REPO/.git" ]]; then
  echo "ERROR: Helen repo workspace not found: $HELEN_REPO" >&2
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "ERROR: invalid GitHub auth for Helen profile (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
  exit 1
fi
gh auth switch -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
actual_login="$(gh api user --jq .login 2>/dev/null || true)"
if [[ "$actual_login" != "$EXPECTED_LOGIN" ]]; then
  echo "ERROR: authenticated as '$actual_login', expected '$EXPECTED_LOGIN' (GH_CONFIG_DIR=$GH_CONFIG_DIR)" >&2
  exit 1
fi

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
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file" || true)"
    if [[ -n "${pid}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      continue
    fi
    rm -f "$pid_file"
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

  echo "$$" > "$pid_file"
  # Run foreground for reliability: background nohup launches can crash under launchd.
  if ! codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.3-codex -C "$HELEN_REPO" "$prompt" >"$log_file" 2>&1; then
    echo "warning: Helen QA Codex run exited non-zero for issue #$num (log: $log_file)" >&2
  fi
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
