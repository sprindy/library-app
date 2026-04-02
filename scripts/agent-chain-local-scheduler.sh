#!/usr/bin/env bash
set -euo pipefail

BASE="/Users/sprindy/.openclaw/workspace/library-app/scripts"
LOCK_DIR="/tmp/openclaw-agent-chain.lock"
LOG_DIR="/Users/sprindy/.openclaw/workspace/logs"
RUN_LOG="$LOG_DIR/agent-chain-local.log"
LOCK_TTL_SECONDS="${AGENT_CHAIN_LOCK_TTL_SECONDS:-10800}"

mkdir -p "$LOG_DIR"

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  local now lock_mtime age stale pid=""
  now="$(date +%s)"
  lock_mtime="$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo "$now")"
  age=$(( now - lock_mtime ))
  stale=0

  if [[ -f "$LOCK_DIR/pid" ]]; then
    pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! kill -0 "$pid" >/dev/null 2>&1; then
      stale=1
    fi
  fi
  if (( age > LOCK_TTL_SECONDS )); then
    stale=1
  fi

  if (( stale == 1 )); then
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR"
    {
      echo "[$(date '+%Y-%m-%d %H:%M:%S %z')] recovered stale lock (age=${age}s, pid=${pid:-unknown})"
    } >>"$RUN_LOG" 2>&1
    return 0
  fi

  return 1
}

if ! acquire_lock; then
  # Another run is active; skip this tick.
  exit 0
fi
echo "$$" > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR" >/dev/null 2>&1 || true' EXIT

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S %z')] cycle start"

  /bin/zsh -lc "source ~/.zshrc >/dev/null 2>&1; bash '$BASE/linus-auto-kickoff.sh'" || echo "linus script failed"
  /bin/zsh -lc "source ~/.zshrc >/dev/null 2>&1; bash '$BASE/leon-auto-review.sh'" || echo "leon script failed"
  /bin/zsh -lc "source ~/.zshrc >/dev/null 2>&1; bash '$BASE/helen-auto-test.sh'" || echo "helen script failed"

  echo "[$(date '+%Y-%m-%d %H:%M:%S %z')] cycle end"
} >>"$RUN_LOG" 2>&1
