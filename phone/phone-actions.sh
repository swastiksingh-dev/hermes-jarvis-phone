#!/data/data/com.termux/files/usr/bin/bash
# 50+ phone actions Hermes can call:  phone-actions.sh <name> [args]
# Each maps to shizuku-bridge.sh + termux-api. Human-like control, no root.
set -uo pipefail
B="$(dirname "$0")/shizuku-bridge.sh"
a="${1:-}"; shift || true
case "$a" in
  wifi_on) bash "$B" --wifi enable;; wifi_off) bash "$B" --wifi disable;;
  bt_on) bash "$B" --bt enable;; bt_off) bash "$B" --bt disable;;
  torch_on) termux-torch on;; torch_off) termux-torch off;;
  volume_up) termux-volume music 15;; volume_down) termux-volume music 3;;
  screenshot) bash "$B" --screenshot "${1:-./shot.png}";;
  notify) termux-notification --title "${1:-Hermes}" --content "${2:-done}";;   # notify "Title" "msg"
  vibrate) termux-vibrate -d "${1:-500}";;
  tts) termux-tts-speak "${*:-task done}";;
  battery) termux-battery-status;;
  location) termux-location;;
  contacts) termux-contact-list;;
  sms_inbox) termux-sms-list -l "${1:-10}";;
  sms_send) termux-sms-send -n "$1" "${*:2}";;
  call) termux-telephony-call "$1";;
  open_url) bash "$B" --open-url "$1";;
  gmail) bash "$B" --gmail-open;;
  play) bash "$B" --play-open "$1";;                                            # play com.whatsapp
  launch) bash "$B" --launch "$1";;
  tap) bash "$B" --tap "$1" "$2";;
  swipe) bash "$B" --swipe "$1" "$2" "$3" "$4";;
  key_home) bash "$B" --key 3;; key_back) bash "$B" --key 4;; key_power) bash "$B" --key 26;;
  type) bash "$B" --input-text "$*";;
  install_apk) bash "$B" --install-apk "$1";;
  download) termux-download "$1";;                                              # download URL
  share) termux-share "$1";;
  clipboard_get) termux-clipboard-get;; clipboard_set) termux-clipboard-set "$1";;
  brightness) bash "$B" --brightness "${1:-120}";;                               # 0-255
  lock) bash "$B" --lock;; wake) bash "$B" --wake;;
  media) bash "$B" --media "${1:-85}";;                                          # 85 toggle 87 next 88 prev
  airplane_on) bash "$B" --airplane 1;; airplane_off) bash "$B" --airplane 0;;
  dnd) bash "$B" --dnd "${1:-off}";;
  wifi_info) bash "$B" --wifi-info;;
  app_list) bash "$B" --app-list "${1:-50}";;
  notif_dump) bash "$B" --notif-dump "${1:-60}";;
  ui_dump) bash "$B" --ui-dump "${1:-./ui_dump.txt}";;                           # see screen as text+bounds
  tap_text) lbl="$*"; bash "$B" --ui-dump /tmp/hermes_ui.txt >/dev/null          # grounded tap by label
    line="$(grep -i -m1 "$lbl" /tmp/hermes_ui.txt || true)"
    [ -n "$line" ] || { echo "tap_text: no match for '$lbl'" >&2; exit 1; }
    xy="$(echo "$line" | sed -E 's/\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\].*/\1 \2 \3 \4/')"
    # shellcheck disable=SC2086
    set -- $xy; bash "$B" --tap "$((( $1 + $3 ) / 2))" "$((( $2 + $4 ) / 2))";;
  shell) bash "$B" --shell "$@";;                                                # guardrailed adb passthrough
  youtube) bash "$B" --youtube "$*";;                                            # app search, + encoded
  recent) bash "$B" --recent;; screenon) bash "$B" --screenon;;
  volkey_up) bash "$B" --volkey 24;; volkey_down) bash "$B" --volkey 25;; mute) bash "$B" --volkey 164;;
  kill_app) bash "$B" --kill-app "$1";;
  whatsapp) bash "$B" --whatsapp "$1" "${*:2}";;
  device_info) bash "$B" --device-info;;
  *) echo "actions: wifi_on wifi_off bt_on bt_off torch_on torch_off volume_up volume_down screenshot notify vibrate tts battery location contacts sms_inbox sms_send call open_url gmail play launch tap tap_text ui_dump shell swipe key_home key_back key_power type install_apk download share clipboard_get clipboard_set brightness lock wake media airplane_on airplane_off dnd wifi_info app_list notif_dump youtube recent screenon volkey_up volkey_down mute kill_app whatsapp device_info";;
esac
