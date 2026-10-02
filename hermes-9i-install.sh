#!/data/data/com.termux/files/usr/bin/bash
# Hermes 9i — Native Termux installer (Realme 9i 4/64GB optimized)
# One-line: curl -fsSL https://raw.githubusercontent.com/swastiksingh-dev/hermes-jarvis-phone/main/hermes-9i-install.sh | bash
# Long-term name: hermes-9i-install.sh (never rename — one-liner depends on it)
#
# Strategy (per upstream docs 2026-10-02):
#  1. Official APT package first — prebuilt, phone compiles nothing.
#  2. pip fallback (needs rust toolchain for maturin builds) if APT fails.
# Our configs (router/phone/jarvis) install either way.
set -uo pipefail

GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[1;33m'; RED='\033[0;31m'; RST='\033[0m'
say(){ echo -e "${CYN}==>${RST} $1"; }
ok(){ echo -e "${GRN}✅ $1${RST}"; }
warn(){ echo -e "${YLW}⚠️ $1${RST}"; }
die(){ echo -e "${RED}❌ $1${RST}"; }

export DEBIAN_FRONTEND=noninteractive
termux-wake-lock 2>/dev/null || true
HERMES_OK=0

say "Realme 9i / 4GB optimized install — native Termux (no proot, no Ollama heavy)"
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo $HOME)"
[ -f "$HERE/termux/fast-mirrors.sh" ] && bash "$HERE/termux/fast-mirrors.sh" || true
pkg update -y
pkg install -y python git curl termux-api jq openssh gnupg 2>&1 | tail -3

# --- Path 1: official APT (prebuilt, no compiling) ---
say "Trying official Hermes APT package..."
mkdir -p "$PREFIX/etc/apt/keyrings"
if curl -fsSL https://hermes-assets.nousresearch.com/releases/termux/stable/key.asc \
    -o "$PREFIX/etc/apt/keyrings/hermes-agent.asc"; then
  FP="$(gpg --show-keys --with-fingerprint "$PREFIX/etc/apt/keyrings/hermes-agent.asc" 2>/dev/null | grep -i fingerprint | head -1 || true)"
  if echo "$FP" | grep -q "C572 B5FD D1A2 9CCF A9A9 12B6 840B 0848 E139 156D"; then
    printf '%s\n' "deb [signed-by=$PREFIX/etc/apt/keyrings/hermes-agent.asc] https://hermes-assets.nousresearch.com/releases/termux/stable hermes-stable main" \
      > "$PREFIX/etc/apt/sources.list.d/hermes-agent.list"
    pkg update -y && pkg install -y hermes-agent && HERMES_OK=1
    ok "Hermes installed via APT"
  else
    warn "APT key fingerprint mismatch — skipping APT path (upstream says stop here for APT)"
  fi
else
  warn "APT key download failed — falling back to pip"
fi

# --- Path 2: pip fallback (needs rust for maturin builds like jiter/firecrawl-anydoc) ---
if [ "$HERMES_OK" = 0 ]; then
  say "APT path unavailable — pip fallback (installs rust toolchain, takes longer)..."
  pkg install -y rust clang libffi openssl pkg-config make nodejs ripgrep ffmpeg 2>&1 | tail -3 || warn "build tools partial, continuing"
  _f="$(find $PREFIX/lib/python3.* -name "_sysconfigdata*.py" 2>/dev/null | head -1 || true)"
  if [ -n "${_f:-}" ] && [ -f "$_f" ]; then
    cp "$_f" "$_f.backup" 2>/dev/null || true
    sed -i 's|-fno-openmp-implicit-rpath||g' "$_f" || true
    rm -rf $PREFIX/lib/python3.*/__pycache__ 2>/dev/null || true
    ok "patched python sysconfig"
  fi
  if [ ! -d "$HOME/hermes-agent" ]; then
    say "cloning hermes-agent (shallow, no history to save space)..."
    git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent" \
      || { die "clone failed — check connection and rerun"; }
  else
    say "hermes-agent exists, updating..."
    cd "$HOME/hermes-agent" && git pull --ff-only || warn "pull failed, using existing"
    cd "$HOME"
  fi
  cd "$HOME/hermes-agent"
  python -m venv venv --without-pip 2>/dev/null || python -m venv venv
  # shellcheck disable=SC1091
  source venv/bin/activate
  curl -fsSL https://bootstrap.pypa.io/get-pip.py | python - 2>&1 | tail -2 || python -m ensurepip || true
  python -m pip install --upgrade pip setuptools wheel
  export ANDROID_API_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null || echo 33)"
  say "ANDROID_API_LEVEL=$ANDROID_API_LEVEL"
  # termux extra only — NOT [all] (too heavy for 4GB). upstream has no
  # constraints-termux.txt, use -c only if the file exists.
  if [ -f constraints-termux.txt ]; then
    python -m pip install --prefer-binary -e '.[termux]' -c constraints-termux.txt && HERMES_OK=1
  else
    python -m pip install --prefer-binary -e '.[termux]' && HERMES_OK=1
  fi
  [ "$HERMES_OK" = 1 ] && ln -sf "$HOME/hermes-agent/venv/bin/hermes" "$PREFIX/bin/hermes" || true
  deactivate 2>/dev/null || true
fi

# --- Our configs install regardless, so bridge/router/jarvis always land ---
for d in router phone jarvis termux; do
  if [ -d "$HERE/$d" ]; then mkdir -p "$HOME/hermes-9i/$d"; cp -r "$HERE/$d/"* "$HOME/hermes-9i/$d/" 2>/dev/null || true; fi
done
mkdir -p "$HOME/hermes-9i/memory" "$HOME/hermes-9i/logs" "$HOME/hermes-9i/creations"

if [ "$HERMES_OK" = 1 ]; then ok "Hermes installed"; else die "Hermes binary install failed — configs still copied, see troubleshooting"; fi
echo ""
echo -e "${YLW}NEXT (2 sessions):${RST}"
echo "  Session 1 (9router): bash ~/hermes-9i/router/start-9router.sh  # dashboard :20128, connect providers"
echo "  Session 2 (hermes):  hermes setup   # Custom endpoint http://127.0.0.1:20128/v1"
echo "                       hermes"
echo "  Jarvis loop:         bash ~/hermes-9i/jarvis/jarvis-loop.sh --once   # test"
echo "  Phone bridge:        bash ~/hermes-9i/phone/shizuku-bridge.sh --check"
echo "  Full guide:          see SETUP.md"
termux-wake-unlock 2>/dev/null || true
[ "$HERMES_OK" = 1 ]
