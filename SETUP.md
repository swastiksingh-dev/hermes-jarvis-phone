# SETUP — Realme 9i 4/64GB, no-root, Shizuku wireless debugging

## 0. What you need

- Realme 9i 4G 4/64, Android 13/14, **not rooted** (root never required).
- Termux **from F-Droid** (Play version is stale and breaks `pkg`).
- Termux:API + Termux:Boot apks (F-Droid). Shizuku app (Play Store).
- OpenRouter free key: https://openrouter.ai/keys → `sk-or-v1-…`
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

What it does: `pkg` minimal set, Python 3.13 psutil patch, shallow clone
`NousResearch/hermes-agent`, `venv`, `pip install -e '.[termux]'`, symlink
`hermes`, copy `router/ phone/ jarvis/ termux/` to `~/hermes-9i/`.
It does **not** install proot-Ubuntu or Ollama (both OOM on 4GB).

## 3. Router — Session 1 (new Termux session, swipe right → New session)

```bash
bash ~/hermes-9i/router/start-9router.sh
# paste key once → saved 0600 to ~/.hermes-9i-router-key
curl http://127.0.0.1:4000/health   # {"status":"ok","models":[…]}
```

- Reorder fallback: `~/hermes-9i/router/models.txt` (line 1 = primary).
- Override without editing: `ROUTER_MODELS="a:free,b:free" ROUTER_PORT=4000 bash …/start-9router.sh`.
- Leave this session running. It uses ~30MB (stdlib `http.server`, no litellm).

## 4. Hermes — Session 2 (point at local endpoint)

```bash
hermes setup
# provider: Custom endpoint
# base_url: http://127.0.0.1:4000/v1
# api_key:  local-9router
# model:    qwen/qwen3-235b-a22b:free
```

Or merge `~/hermes-9i/jarvis/hermes-config.yaml` into `~/.hermes/config.yaml`
(`provider: custom` is required or Hermes may ignore `base_url`).

## 5. Phone bridge (phone-as-user, like OpenClaw)

```bash
bash ~/hermes-9i/phone/shizuku-bridge.sh --check
# want: termux-api OK / rish/shizuku OK / adb shell OK
bash ~/hermes-9i/phone/phone-actions.sh          # list 30 actions
bash ~/hermes-9i/phone/phone-actions.sh gmail
bash ~/hermes-9i/phone/phone-actions.sh screenshot ./shot.png
```

Email = open Gmail app + screenshot + summarize. No app-passwords.
Apps = `play <pkg>` intent + screenshot, `download <url>` + `install_apk`.

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
| Router `429/529` loop | move a higher-limit `:free` model to line 1 of `models.txt` |
| Hermes ignores `base_url` | set `provider: custom` (see `hermes-config.yaml`) |
| `hermes` OOM / killed | kill proot/Ollama, one hermes at a time, `CYCLE_MIN=10` |
| Play Store Termux errors | uninstall, reinstall from F-Droid |
| Battery kills loop | Unrestricted battery, `termux-wake-lock`, keep device charging |
