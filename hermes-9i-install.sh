#!/data/data/com.termux/files/usr/bin/bash
# Hermes 9i — Native Termux installer (Realme 9i 4/64GB optimized)
# One-line: curl -fsSL https://raw.githubusercontent.com/swastiksingh-dev/hermes-jarvis-phone/main/hermes-9i-install.sh | bash
# Long-term name: hermes-9i-install.sh (never rename — one-liner depends on it)
set -euo pipefail

GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[1;33m'; RED='\033[0;31m'; RST='\033[0m'
say(){ echo -e "${CYN}==>${RST} $1"; }
ok(){ echo -e "${GRN}✅ $1${RST}"; }
warn(){ echo -e "${YLW}⚠️ $1${RST}"; }

export DEBIAN_FRONTEND=noninteractive
termux-wake-lock 2>/dev/null || true

say "Realme 9i / 4GB optimized install — native Termux (no proot, no Ollama heavy)"
# fastest mirror first: slow pkg downloads are almost always a bad mirror pick
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo $HOME)"
[ -f "$HERE/termux/fast-mirrors.sh" ] && bash "$HERE/termux/fast-mirrors.sh" || true
pkg update -y
# minimal deps only: 4GB RAM cannot afford rust+clang full chain unless needed
pkg install -y python git curl termux-api jq openssh 2>&1 | tail -5

# optional heavy build tools only if hermes needs compile (psutil etc)
pkg install -y clang libffi openssl pkg-config make 2>&1 | tail -3 || warn "build tools partial, continuing"

# Python 3.13 psutil fix for Termux (from old install.sh)
_f="$(find $PREFIX/lib/python3.* -name "_sysconfigdata*.py" 2>/dev/null | head -1 || true)"
if [ -n "${_f:-}" ] && [ -f "$_f" ]; then
  cp "$_f" "$_f.backup" 2>/dev/null || true
  sed -i 's|-fno-openmp-implicit-rpath||g' "$_f" || true
  rm -rf $PREFIX/lib/python3.*/__pycache__ 2>/dev/null || true
  ok "patched python sysconfig"
fi

if [ ! -d "$HOME/hermes-agent" ]; then
  say "cloning hermes-agent (shallow, no history to save space)..."
  git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent"
else
  say "hermes-agent exists, updating..."
  cd "$HOME/hermes-agent" && git pull --ff-only || warn "pull failed, using existing"
  cd "$HOME"
fi

cd "$HOME/hermes-agent"
python -m venv venv --without-pip 2>/dev/null || python -m venv venv
source venv/bin/activate
curl -fsSL https://bootstrap.pypa.io/get-pip.py | python - 2>&1 | tail -2 || python -m ensurepip || true
python -m pip install --upgrade pip setuptools wheel

export ANDROID_API_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null || echo 33)"
say "ANDROID_API_LEVEL=$ANDROID_API_LEVEL"

# termux extra only — NOT [all] (too heavy for 4GB). prefer-binary skips slow source builds.
# NOTE: upstream has no constraints-termux.txt (verified 2026-10-01), so only
# use -c when the file actually exists.
if [ -f constraints-termux.txt ]; then
  python -m pip install --prefer-binary -e '.[termux]' -c constraints-termux.txt
else
  python -m pip install --prefer-binary -e '.[termux]'
fi

ln -sf "$HOME/hermes-agent/venv/bin/hermes" "$PREFIX/bin/hermes" || true

# copy 9i configs from this repo if present (when cloned via hermess-agents-mobile)
# layout: this installer lives alongside router/, phone/, jarvis/, termux/
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo $HOME)"
for d in router phone jarvis termux; do
  if [ -d "$SCRIPT_DIR/$d" ]; then mkdir -p "$HOME/hermes-9i/$d"; cp -r "$SCRIPT_DIR/$d/"* "$HOME/hermes-9i/$d/" 2>/dev/null || true; fi
done
mkdir -p "$HOME/hermes-9i/memory" "$HOME/hermes-9i/logs" "$HOME/hermes-9i/creations"

ok "Hermes installed (native, low-RAM)"
echo ""
echo -e "${YLW}NEXT (2 sessions):${RST}"
echo "  Session 1 (9router): bash ~/hermes-9i/router/start-9router.sh  # dashboard :20128, connect providers"
echo "  Session 2 (hermes):  hermes setup   # Custom endpoint http://127.0.0.1:20128/v1"
echo "                       hermes"
echo "  Jarvis loop:         bash ~/hermes-9i/jarvis/jarvis-loop.sh --once   # test"
echo "  Phone bridge:        bash ~/hermes-9i/phone/shizuku-bridge.sh --check"
echo "  Full guide:          see SETUP.md"
termux-wake-unlock 2>/dev/null || true
