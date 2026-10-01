#!/data/data/com.termux/files/usr/bin/bash
# Shizuku bridge — use phone LIKE A USER (OpenClaw-phone-control pattern, Hermes edition)
# NO-ROOT ONLY. Works with Shizuku + Wireless debugging. No su, no magisk.
# Setup (once, no PC, no root):
#  1. Settings > About > tap Build Number 7x (Developer options)
#  2. Settings > Developer options > Wireless debugging ON
#  3. Shizuku app > Pairing > enter code from Wireless debugging > Pair
#  4. Shizuku app > Start (uses Wireless debugging, survives until reboot)
#  5. Shizuku app > "Use Shizuku in terminal apps" > Export files (creates rish in Termux)
# After reboot just repeat step 4 (Start), no re-pair needed.
set -uo pipefail
RISH="${RISH:-rish}"

has_rish(){ command -v rish >/dev/null 2>&1; }
adb_shell(){
  # NO ROOT: rish first (Shizuku wireless debugging), plain adb second. Never su.
  if command -v rish >/dev/null 2>&1; then rish -c "$*";
  elif command -v adb >/dev/null 2>&1; then adb shell "$@";
  else echo "ERROR: no rish/adb. Do Shizuku Export step." >&2; return 1; fi;
}

case "${1:-}" in
  --check)
    echo "== shizuku check =="
    command -v termux-api-start 2>/dev/null && echo "termux-api: OK" || echo "termux-api: MISSING (pkg install termux-api + install Termux:API apk)"
    has_rish && echo "rish/shizuku: OK" || echo "rish/shizuku: MISSING (do Shizuku Export step)"
    adb_shell "echo adb_ok" && echo "adb shell: OK" || echo "adb shell: FAIL"
    ;;
  --launch) shift; adb_shell "monkey -p $1 -c android.intent.category.LAUNCHER 1" ;;       # --launch com.google.android.gm
  --open-url) shift; adb_shell "am start -a android.intent.action.VIEW -d '$1'" ;;          # --open-url https://...
  --intent) shift; adb_shell "am start $*" ;;                                                # raw am args
  --screenshot) adb_shell "screencap -p /sdcard/hermes_shot.png"; cp /sdcard/hermes_shot.png "${2:-./shot.png}" 2>/dev/null || termux-screenshot -p "${2:-./shot.png}" ;;
  --notif-dump) adb_shell "dumpsys notification | head -n ${2:-100}" ;;
  --wifi) adb_shell "svc wifi ${2:-enable}" ;;
  --bt) adb_shell "svc bluetooth ${2:-enable}" ;;
  --volume) adb_shell "media volume --set ${2:-3} --volume ${3:-10}" ;;                       # --volume 3 10
  --input-text) shift; adb_shell "input text '$(echo "$*" | sed "s/ /%s/g")'" ;;
  --tap) adb_shell "input tap $2 $3" ;;
  --swipe) adb_shell "input swipe $2 $3 $4 $5 ${6:-300}" ;;
  --key) adb_shell "input keyevent $2" ;;                                                    # 3=home 4=back 26=power
  --install-apk) adb_shell "pm install -r '$2'" ;;
  --gmail-open) adb_shell "am start -n com.google.android.gm/.ConversationListActivityGmail" ;;
  --play-open) shift; adb_shell "am start -a android.intent.action.VIEW -d 'market://details?id=$1'" ;;
  --brightness) adb_shell "settings put system screen_brightness ${2:-120}" ;;                 # 0-255
  --lock) adb_shell "input keyevent 26" ;;
  --wake) adb_shell "input keyevent 224" ;;
  --media) adb_shell "input keyevent ${2:-85}" ;;                                              # 85 play/pause 87 next 88 prev
  --airplane) adb_shell "settings put global airplane_mode_on ${2:-0}; am broadcast -a android.intent.action.AIRPLANE_MODE --ez state ${2:-false} >/dev/null" ;;
  --dnd) adb_shell "cmd notification set_dnd ${2:-off}" ;;                                     # off|priority|alarms|total
  --wifi-info) adb_shell "dumpsys wifi | grep -m5 -i 'mWifiInfo\|SSID\|RSSI'" ;;
  --app-list) adb_shell "pm list packages -3 | head -n ${2:-50}" ;;                            # third-party apps
  *) cat <<'H'
usage: shizuku-bridge.sh --check | --launch PKG | --open-url URL | --intent AM_ARGS
  --screenshot [out] | --notif-dump [lines] | --wifi enable|disable | --bt enable|disable
  --volume STREAM LVL | --input-text TXT | --tap X Y | --swipe X1 Y1 X2 Y2 | --key CODE
  --install-apk PATH | --gmail-open | --play-open PKG
  --brightness 0-255 | --lock | --wake | --media 85 | --airplane 0|1 | --dnd off|priority
  --wifi-info | --app-list [n]
H
;;
esac
