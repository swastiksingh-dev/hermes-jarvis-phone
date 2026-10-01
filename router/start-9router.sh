#!/data/data/com.termux/files/usr/bin/bash
# Session 1: real 9Router (https://github.com/decolua/9router, https://9router.com).
# npm gateway on localhost:20128 with dashboard-managed providers + 3-tier fallback.
# Usage:  bash ~/hermes-9i/router/start-9router.sh   (leave this session running)
set -euo pipefail
command -v node >/dev/null 2>&1 || { echo "node missing -> pkg install -y nodejs"; exit 1; }
if ! command -v 9router >/dev/null 2>&1; then
  echo "installing 9router (once)..."
  npm install -g 9router
fi
export PORT="${PORT:-20128}"
export NODE_OPTIONS="${NODE_OPTIONS:---dns-result-order=ipv4first}"   # Termux IPv4 DNS fix
termux-wake-lock 2>/dev/null || true
echo "dashboard:  http://127.0.0.1:20128/dashboard  (connect providers, build combos, copy API key)"
echo "endpoint for hermes: http://127.0.0.1:20128/v1  provider: custom"
echo "note: 9Router is a Next.js app and heavier than a tiny proxy - if the 9i"
echo "struggles, run it only while Hermes is working, not 24/7."
exec 9router
