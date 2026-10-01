#!/data/data/com.termux/files/usr/bin/bash
# Optional remote trigger: Telegram messages -> jarvis task inbox. No gateway needed.
# Setup: talk to @BotFather, create bot, then:
#   echo "123456:ABC..." > ~/.hermes-9i-tg-token; chmod 600 ~/.hermes-9i-tg-token
# Run:  bash ~/hermes-9i/phone/telegram-watch.sh   (keep in its own session)
# Every message becomes "- [ ] <text>" in tasks.md and a Termux notification.
set -uo pipefail
H9="$HOME/hermes-9i"
TOK="${TELEGRAM_BOT_TOKEN:-$(cat ~/.hermes-9i-tg-token 2>/dev/null || true)}"
[ -n "$TOK" ] || { echo "set TELEGRAM_BOT_TOKEN or ~/.hermes-9i-tg-token (see header)"; exit 1; }
OFF=0
while true; do
  RESP="$(curl -s -m 35 "https://api.telegram.org/bot$TOK/getUpdates?offset=$OFF&timeout=30" || true)"
  ROWS="$(echo "$RESP" | jq -r '.result[]? | "\(.update_id) tri \(.message.chat.id) tri \(.message.text // empty)"' 2>/dev/null || true)"
  [ -n "$ROWS" ] || continue
  while IFS= read -r row; do
    id="${row%% tri *}"; rest="${row#* tri }"; chat="${rest%% tri *}"; txt="${rest#* tri }"
    OFF=$((id + 1))
    [ -n "$txt" ] || continue
    echo "- [ ] (tg) $txt" >> "$H9/jarvis/tasks.md"
    termux-notification --title "Jarvis queued" --content "$txt" 2>/dev/null || true
    curl -s -m 10 --data-urlencode "chat_id=$chat" --data-urlencode "text=queued: $txt" "https://api.telegram.org/bot$TOK/sendMessage" >/dev/null || true
  done <<< "$ROWS"
done
