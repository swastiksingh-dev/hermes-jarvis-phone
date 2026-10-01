#!/data/data/com.termux/files/usr/bin/bash
# Start 9Router in its OWN Termux session (Session 1). Low RAM.
# Usage:  bash ~/hermes-9i/router/start-9router.sh
set -euo pipefail
cd "$(dirname "$0")"
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  if [ -f "$HOME/.hermes-9i-router-key" ]; then export OPENROUTER_API_KEY="$(cat $HOME/.hermes-9i-router-key)"
  else
    echo "Paste OpenRouter key (sk-or-v1-... from https://openrouter.ai/keys):"
    read -r OPENROUTER_API_KEY
    echo "$OPENROUTER_API_KEY" > "$HOME/.hermes-9i-router-key"
    chmod 600 "$HOME/.hermes-9i-router-key"
  fi
fi
export ROUTER_PORT="${ROUTER_PORT:-4000}"
termux-wake-lock 2>/dev/null || true
echo "[9router] http://127.0.0.1:$ROUTER_PORT/v1  -> Hermes provider: custom"
python3 hermes-9i-router.py
