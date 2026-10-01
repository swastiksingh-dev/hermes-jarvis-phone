#!/data/data/com.termux/files/usr/bin/bash
# Pick the fastest Termux mirror and lock it in. Fixes slow/stuck pkg downloads.
# Same file format termux-change-repo uses ($PREFIX/etc/termux/chosen_mirrors).
# Usage:  bash ~/hermes-9i/termux/fast-mirrors.sh
#         bash ~/hermes-9i/termux/fast-mirrors.sh --restore
set -uo pipefail
CF="$PREFIX/etc/termux/chosen_mirrors"

if [ "${1:-}" = "--restore" ]; then
  if [ -f "$CF.backup-9i" ]; then cp "$CF.backup-9i" "$CF"; echo "restored previous mirror setting"; pkg update -y
  else echo "no backup found"; exit 1; fi
  exit 0
fi

# name|MAIN|ROOT|X11  (sources: termux-packages wiki Mirrors page)
CANDIDATES="
cf|https://packages-cf.termux.dev/apt/termux-main|https://packages-cf.termux.dev/apt/termux-root|https://packages-cf.termux.dev/apt/termux-x11
niranjan-in|https://termux.niranjan.co/termux-main|https://termux.niranjan.co/termux-root|https://termux.niranjan.co/termux-x11
ravidwivedi-in|https://mirrors.ravidwivedi.in/termux/termux-main|https://mirrors.ravidwivedi.in/termux/termux-root|https://mirrors.ravidwivedi.in/termux/termux-x11
sahilister-in|https://mirrors.in.sahilister.net/termux/termux-main|https://mirrors.in.sahilister.net/termux/termux-root|https://mirrors.in.sahilister.net/termux/termux-x11
albony-in|https://mirror.nag.albony.in/termux/termux-main|https://mirror.nag.albony.in/termux/termux-root|https://mirror.nag.albony.in/termux/termux-x11
saswata-in|https://mirrors.saswata.cc/termux/termux-main|https://mirrors.saswata.cc/termux/termux-root|https://mirrors.saswata.cc/termux/termux-x11
freedif-sg|https://mirror.freedif.org/termux/termux-main|https://mirror.freedif.org/termux/termux-root|https://mirror.freedif.org/termux/termux-x11
grimler-eu|https://grimler.se/termux/termux-main|https://grimler.se/termux/termux-root|https://grimler.se/termux/termux-x11
"

best=""; best_t="999"; best_m=""; best_r=""; best_x=""
while IFS='|' read -r name m r x; do
  [ -z "$name" ] && continue
  t="$(curl -s -m 12 -o /dev/null -w '%{time_total} %{http_code}' "$m/dists/stable/InRelease" 2>/dev/null || echo "999 000")"
  code="${t##* }"; secs="${t%% *}"
  echo "$name: ${secs}s (http $code)"
  if [ "$code" = "200" ] && awk "BEGIN{exit !($secs < $best_t)}"; then
    best="$name"; best_t="$secs"; best_m="$m"; best_r="$r"; best_x="$x"
  fi
done <<< "$(echo "$CANDIDATES" | grep '|')"

[ -n "$best" ] || { echo "no mirror reachable - check internet connection"; exit 1; }
echo "winner: $best (${best_t}s)"

[ -e "$CF" ] && [ ! -e "$CF.backup-9i" ] && cp -r "$CF" "$CF.backup-9i" && echo "backed up old setting"
[ -d "$CF" ] && rm -rf "$CF"   # group dir -> replace with single fast mirror
printf 'WEIGHT=10 MAIN="%s" ROOT="%s" X11="%s"\n' "$best_m" "$best_r" "$best_x" > "$CF"
echo "locked to $best. refreshing package lists..."
pkg update -y
