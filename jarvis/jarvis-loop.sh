#!/data/data/com.termux/files/usr/bin/bash
# Jarvis loop — always-on daemon for Realme 9i 4GB.
# Usage: bash jarvis-loop.sh --once   (test one cycle)
#        bash jarvis-loop.sh          (infinite, low-CPU: 1 cycle / 5 min)
#        CYCLE_MIN=10 bash jarvis-loop.sh
set -uo pipefail
H9="$HOME/hermes-9i"; LOG="$H9/logs/jarvis.log"; MEM="python3 $H9/jarvis/memory.py"
mkdir -p "$H9/logs" "$H9/memory" "$H9/creations"
CYCLE_MIN="${CYCLE_MIN:-5}"

once(){
  echo "=== $(date) cycle ===" | tee -a "$LOG"
  # 1. memory context (last 5)
  CTX="$($MEM recall "" 5 2>/dev/null | head -20 || true)"
  # 2. phone status (cheap) + battery guard for 4GB device
  BAT="$(termux-battery-status 2>/dev/null | tr -d '\n' | cut -c1-200 || echo no-api)"
  case "$BAT" in *'"percentage": 1'[0-9]*|*'"percentage": [0-9]'*) echo "battery low, memory-only cycle" | tee -a "$LOG"; $MEM remember "low-battery cycle $(date +%F_%T)" 2>/dev/null || true; return 0;; esac
  # 3. build prompt for hermes (uses local 9router endpoint)
  PROMPT="You are Jarvis on Realme 9i (4GB, no-root). Context memory: $CTX. Battery: $BAT. Do ONE small task from ~/hermes-9i/jarvis/tasks.md inbox, using phone/phone-actions.sh for phone control. Keep output <30 lines. Remember key facts via: python3 ~/hermes-9i/jarvis/memory.py remember \"fact\"."
  if command -v hermes >/dev/null 2>&1; then
    timeout 600 hermes "$PROMPT" 2>&1 | tee -a "$LOG" | tail -30
    $MEM remember "cycle $(date +%F_%T) done" 2>/dev/null || true
  else
    echo "hermes not found, run installer first" | tee -a "$LOG"
    return 1
  fi
}
if [ "${1:-}" = "--once" ]; then once; exit $?; fi
termux-wake-lock 2>/dev/null || true
echo "[jarvis] infinite loop every ${CYCLE_MIN}min. logs: $LOG"
while true; do once || true; sleep "$((CYCLE_MIN*60))"; done
