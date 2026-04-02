#!/usr/bin/env bash
set -euo pipefail

# Auto-route bridge for Linus:
# 1) ensure local branch kickoff for ANY open issue assigned to Linus
# 2) automatically start Codex implementation with retry-safe cooldowns.

REPO="sprindy/library-app"
BASE="/Users/sprindy/.openclaw/workspace/agent-workspaces"
LINUS_REPO="$BASE/linus/library-app"
RUN_DIR="$BASE/linus/runs"
STATE_DIR="$RUN_DIR/state"
export GH_CONFIG_DIR="$BASE/.gh-profiles/linus"
EXPECTED_LOGIN="CoderLinus"
CRON_JOB_ID="${LINUS_KICKOFF_CRON_JOB_ID:-a47cd449-b172-4c45-8649-7059a8202548}"
AUTO_DISABLE_ON_OPEN_PR="${LINUS_AUTO_DISABLE_ON_OPEN_PR:-1}"
AUTO_AUTH_HEAL="${LINUS_AUTO_AUTH_HEAL:-1}"
CODEX_TIMEOUT_SECONDS="${LINUS_CODEX_TIMEOUT_SECONDS:-2100}"
RETRY_COOLDOWN_SECONDS="${LINUS_RETRY_COOLDOWN_SECONDS:-900}"

# Prevent shell-exported GH_TOKEN/GITHUB_TOKEN from overriding role profile auth.
unset GH_TOKEN
unset GITHUB_TOKEN

KICKOFF_MARKER="[linus-local-started:v1]"
IMPL_MARKER="[linus-impl-started:v1]"
FAIL_MARKER="[linus-impl-failed:v1]"

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

  # Normalize timeout exits so caller can detect and comment clearly.
  if [[ "$rc" -eq 143 || "$rc" -eq 137 ]]; then
    return 124
  fi
  return "$rc"
}

ensure_role_auth() {
  local pat="${CODER_PAT:-}"

  if ! gh auth status -h github.com >/dev/null 2>&1; then
    if [[ "$AUTO_AUTH_HEAL" == "1" && -n "$pat" ]]; then
      gh auth logout -h github.com -u "$EXPECTED_LOGIN" >/dev/null 2>&1 || true
      printf '%s' "$pat" | gh auth login -h github.com --with-token -p https >/dev/null
    else
      echo "ERROR: invalid GitHub auth for Linus profile (GH_CONFIG_DIR=$GH_CONFIG_DIR). Export CODER_PAT to auto-heal." >&2
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

need_bin gh
need_bin codex
need_bin jq
need_bin git
ensure_role_auth

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
  if (( cooldown_ref > 0 && now_epoch - cooldown_ref < RETRY_COOLDOWN_SECONDS )); then
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

  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$marker_file"

  gh issue comment "$num" --repo "$REPO" --body "$IMPL_MARKER Codex implementation started.

- Branch: \`$branch\`
- Log: \`$log_file\`
- Next: push + PR creation with \`Fixes #$num\`." >/dev/null || true

  echo "$$" > "$pid_file"
  codex_rc=0
  (
    cd "$LINUS_REPO"
    # Foreground execution is more reliable under launchd than detached nohup jobs.
    run_with_timeout "$CODEX_TIMEOUT_SECONDS" \
      codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.3-codex "$prompt"
  ) >"$log_file" 2>&1 || codex_rc=$?
  rm -f "$pid_file"

  linked_prs_after=$(gh pr list --repo "$REPO" --state open --search "#${num}" --json number --jq 'length')
  if [[ "$linked_prs_after" != "0" ]]; then
    echo "implementation finished for issue #$num (PR detected, log: $log_file)"
    acted=1
    continue
  fi

  if [[ "$codex_rc" -eq 124 ]]; then
    fail_reason="timed out after ${CODEX_TIMEOUT_SECONDS}s"
  elif [[ "$codex_rc" -ne 0 ]]; then
    fail_reason="exited with code ${codex_rc}"
  else
    fail_reason="completed without opening a PR"
  fi

  gh issue comment "$num" --repo "$REPO" --body "$FAIL_MARKER Implementation attempt did not produce a PR.

- Branch: \`$branch\`
- Result: $fail_reason
- Log: \`$log_file\`
- Next: retry after cooldown (\`${RETRY_COOLDOWN_SECONDS}s\`) or push/manual PR." >/dev/null || true
  echo "warning: issue #$num implementation attempt failed ($fail_reason, log: $log_file)" >&2
  acted=1
done <<< "$ISSUES"

if [[ "$needs_impl" == "0" ]]; then
  disable_kickoff_cron_if_configured "all assigned open issues already have open PRs"
fi

[[ "$acted" == "1" ]] && exit 0
exit 0
