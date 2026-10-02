# SETUP — Realme 9i 4/64GB, no-root, Shizuku wireless debugging

## 0. What you need

- Realme 9i 4G 4/64, Android 13/14, **not rooted** (root never required).
- Termux **from F-Droid** (Play version is stale and breaks `pkg`).
- Termux:API + Termux:Boot apks (F-Droid). Shizuku app (Play Store).
- OpenRouter free key: not needed. 9Router connects providers (free tiers included) in its dashboard.
- 3GB free, Wi-Fi, 10 min.

## 1. Shizuku, no PC (do first — Hermes needs it later)

1. Settings → About phone → tap **Build number** 7×.
2. Settings → Developer options → **Wireless debugging ON**.
3. Shizuku → **Pairing** → enter the 6-digit code from Wireless debugging → Pair.
4. Shizuku → **Start** (uses wireless debugging; survives until reboot).
5. Shizuku → **Use Shizuku in terminal apps** → Export files (creates `rish`).
6. Termux: `termux-setup-storage`. App info → Battery → **Unrestricted** for Termux + Shizuku.
7. After every reboot: only step 4 again. Re-pair only if the code expired.

## 2. Install Hermes (native, 4GB-safe)

```bash
curl -fsSL https://raw.githubusercontent.com/swastiksingh-dev/hermes-jarvis-phone/main/hermes-9i-install.sh | bash
```

What it does: fastest mirror first, then the **official Hermes APT package**
(prebuilt — the phone compiles nothing), with a pip fallback that installs
the Rust toolchain for maturin builds. Then it copies `router/ phone/
jarvis/ termux/` to `~/hermes-9i/`. No proot-Ubuntu or Ollama (both OOM on 4GB).
Upstream flags the APT package as occasionally broken — if `hermes` is still
missing after install, the pip fallback in the same script covers it; rerun
the installer and read the last lines.

## 3. 9Router — Session 1 (new Termux session, swipe right → New session)

```bash
bash ~/hermes-9i/router/start-9router.sh
# installs 9router via npm on first run, then serves http://127.0.0.1:20128
```

Open `http://127.0.0.1:20128/dashboard` in a browser, connect free providers
(Kiro AI ~50 credits/mo, OpenCode Free no-auth), build a fallback combo
(subscription → cheap → free), and copy the API key. Leave this session
running. 9Router is a Next.js app, heavier than a tiny proxy — if the 9i
struggles, run it only while Hermes is working.

## 4. Hermes — Session 2 (point at local endpoint)

```bash
hermes setup
# provider: Custom endpoint
# base_url: http://127.0.0.1:20128/v1
# api_key:  <paste key from 9Router dashboard>
# model:    kr/claude-sonnet-4.5   (or another id from router/models.txt)
```

Or merge `~/hermes-9i/jarvis/hermes-config.yaml` into `~/.hermes/config.yaml`
(`provider: custom` is required or Hermes may ignore `base_url`).

## 5. Phone bridge (phone-as-user, like OpenClaw)

```bash
bash ~/hermes-9i/phone/shizuku-bridge.sh --check
# want: termux-api OK / rish/shizuku OK / adb shell OK
bash ~/hermes-9i/phone/phone-actions.sh          # list 50+ actions
bash ~/hermes-9i/phone/phone-actions.sh gmail
bash ~/hermes-9i/phone/phone-actions.sh screenshot ./shot.png
```

Email = open Gmail app + screenshot + summarize. No app-passwords.
Apps = `play <pkg>` intent + screenshot, `download <url>` + `install_apk`.
Grounded control = `ui_dump` lists on-screen text with bounds, `tap_text "<label>"`
taps the center of the match. Rules in `jarvis/phone-rules.md`: dump before
every tap, re-dump after, scroll-and-retry max 3, never stop after one launch.
Raw `shell` runs any adb command but refuses destructive patterns (`rm -rf /`,
`mkfs`, `dd if=`, fork bombs). Shizuku acting up? `shizuku-bridge.sh --repair`
prints the exact fix (storage perm, dex export, Start).

Optional: Telegram as a remote inbox. Create a bot with `@BotFather`, save the
token to `~/.hermes-9i-tg-token`, run `phone/telegram-watch.sh` in its own
session. Messages land in `tasks.md` for the next loop cycle.

## 6. Jarvis loop (always-on)

```bash
bash ~/hermes-9i/jarvis/jarvis-loop.sh --once   # one test cycle
bash ~/hermes-9i/jarvis/jarvis-loop.sh          # every 5 min, logs ~/hermes-9i/logs/jarvis.log
CYCLE_MIN=10 bash ~/hermes-9i/jarvis/jarvis-loop.sh
```

- Edit inbox: `~/hermes-9i/jarvis/tasks.md`. Memory: `python3 ~/hermes-9i/jarvis/memory.py recall "x"`.
- Boot: `bash ~/hermes-9i/termux/boot-autostart.sh` (needs Termux:Boot apk).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `rish not found` | Shizuku → Export files again, restart Termux |
| Shizuku stopped | Shizuku → Start; keep Wireless debugging ON |
| Router `401` | bad key → `rm ~/.hermes-9i-router-key`, rerun starter |
| 9Router quota/rate-limit loop | check the dashboard quota tracker, adjust the combo fallback order |
| Hermes ignores `base_url` | set `provider: custom` (see `hermes-config.yaml`) |
| `hermes` OOM / killed | kill proot/Ollama, one hermes at a time, `CYCLE_MIN=10` |
| Play Store Termux errors | uninstall, reinstall from F-Droid |
| `pkg` slow or stuck | run `bash ~/hermes-9i/termux/fast-mirrors.sh` (tests mirrors, locks fastest; `--restore` undoes it) |
| `npm install` slow | normal once (~100MB Next.js app) — stay on Wi-Fi; flags `--no-audit --no-fund` already skip extras |
| `pip install` building from source | installer now uses `--prefer-binary` plus Termux `rust`; maturin failures mean the Rust toolchain step was skipped — rerun the installer |
| `constraints-termux.txt` missing | expected — upstream removed it; installer uses plain `.[termux]` automatically |
| Battery kills loop | Unrestricted battery, `termux-wake-lock`, keep device charging |
