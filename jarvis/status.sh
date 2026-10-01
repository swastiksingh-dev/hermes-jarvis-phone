#!/data/data/com.termux/files/usr/bin/bash
# One-glance health for the 9i stack. Run: bash ~/hermes-9i/jarvis/status.sh
set -uo pipefail
H9="$HOME/hermes-9i"
echo "== 9router =="; code="$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:20128/v1/models || true)"; echo "v1/models http: $code (401 = up, needs dashboard key; 000 = down)"
echo "== hermes =="; command -v hermes >/dev/null && echo "hermes: OK" || echo "hermes: MISSING"
echo "== phone =="; bash "$H9/phone/shizuku-bridge.sh" --check 2>&1 | tail -4
echo "== memory =="; python3 "$H9/jarvis/memory.py" list 3 2>/dev/null || echo "memory: empty"
echo "== logs =="; ls -la "$H9/logs" 2>/dev/null | tail -5 || echo "no logs yet"
