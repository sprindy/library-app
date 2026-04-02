#!/usr/bin/env bash
set -euo pipefail

BASE="/Users/sprindy/.openclaw/workspace/library-app/scripts"
LOCK_DIR="/tmp/openclaw-agent-chain.lock"
LOG_DIR="/Users/sprindy/.openclaw/workspace/logs"
RUN_LOG="$LOG_DIR/agent-chain-local.log"

mkdir -p "$LOG_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # Another run is active; skip this tick.
  exit 0
fi
trap 'rmdir "$LOCK_DIR" >/dev/null 2>&1 || true' EXIT

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S %z')] cycle start"

  /bin/zsh -lc "source ~/.zshrc >/dev/null 2>&1; bash '$BASE/linus-auto-kickoff.sh'" || echo "linus script failed"
  /bin/zsh -lc "source ~/.zshrc >/dev/null 2>&1; bash '$BASE/leon-auto-review.sh'" || echo "leon script failed"
  /bin/zsh -lc "source ~/.zshrc >/dev/null 2>&1; bash '$BASE/helen-auto-test.sh'" || echo "helen script failed"

  echo "[$(date '+%Y-%m-%d %H:%M:%S %z')] cycle end"
} >>"$RUN_LOG" 2>&1
