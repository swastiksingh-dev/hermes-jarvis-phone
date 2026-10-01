<div align="center">

# hermes-jarvis-phone

Hermes agent for Realme 9i 4/64, no root. Native Termux install, Shizuku control through wireless debugging, a local proxy for OpenRouter free models, and a timed loop with SQLite memory.

[![License: MIT](https://img.shields.io/badge/License-MIT-9146ff.svg)](LICENSE)
[![Termux: F-Droid](https://img.shields.io/badge/Termux-F--Droid-ff6b6b.svg)](https://f-droid.org/en/packages/com.termux/)
[![No root](https://img.shields.io/badge/root-not_required-4ecdc4.svg)](SETUP.md)

</div>

## Start here

Full steps are in [SETUP.md](SETUP.md). Short version:

```bash
# 1. install (F-Droid Termux, 5-10 min)
curl -fsSL https://raw.githubusercontent.com/swastiksingh-dev/hermes-jarvis-phone/main/hermes-9i-install.sh | bash

# 2. 9router, in a second Termux session (leave running)
bash ~/hermes-9i/router/start-9router.sh
# dashboard http://127.0.0.1:20128/dashboard -> connect free providers, copy API key

# 3. hermes, in the first session
hermes setup    # custom endpoint: http://127.0.0.1:20128/v1

# 4. checks
bash ~/hermes-9i/phone/shizuku-bridge.sh --check
bash ~/hermes-9i/jarvis/jarvis-loop.sh --once
```

Two sessions is the whole design. Session 1 serves free models on localhost. Session 2 runs Hermes against it.

## How it fits together

| Part | File | What it does |
|---|---|---|
| Installer | `hermes-9i-install.sh` | Native Termux setup for 4GB phones. No proot, no Ollama. |
| Router | `router/start-9router.sh` | Real 9Router (`decolua/9router`) on `127.0.0.1:20128`. Providers and 3-tier fallback live in its dashboard. |
| Router models | `router/models.txt` | Suggested free-first IDs and combo layout. |
| Phone bridge | `phone/shizuku-bridge.sh` | `rish`/`adb` wrapper. Works with Shizuku over wireless debugging, no root. |
| Phone actions | `phone/phone-actions.sh` | 50+ actions Hermes can call: `ui_dump` + `tap_text` grounding, guardrailed `shell`, youtube, recents, kill-app, whatsapp, device info, and the rest. Screen tasks follow `jarvis/phone-rules.md`. |
| Remote trigger (optional) | `phone/telegram-watch.sh` | Bot messages append to the task inbox. Needs a `@BotFather` token, no gateway daemon. |
| Loop | `jarvis/jarvis-loop.sh` | Runs one small task every 5 minutes. Skips heavy work under 20% battery. |
| Health | `jarvis/status.sh` | One-glance check: router, hermes, phone bridge, memory, logs. |
| Memory | `jarvis/memory.py` | SQLite notes, capped at 5000 rows so it stays under 100MB. |
| Tasks | `jarvis/tasks.md` | The inbox. Hermes picks one item per cycle. |
| Hermes config | `jarvis/hermes-config.yaml` | Merge into `~/.hermes/config.yaml`. `provider: custom` matters. |
| Boot | `termux/boot-autostart.sh` | Reinstalls the loop and router after reboot with Termux:Boot. |
| Old scripts | `legacy/` | Earlier installers, kept for reference. They need more RAM than the 9i has. |

## Constraints this repo is built around

Realme 9i 4G, 4GB RAM, 64GB storage, Android 13/14, stock ROM. One Hermes process at a time, one task per cycle, output kept short. The memory backend is plain `LIKE` search instead of embeddings because embeddings cost RAM the phone does not have.

Shizuku setup takes five minutes and no PC: enable wireless debugging, pair Shizuku, press Start, export files for Termux. After a reboot you only press Start again. The exact taps are in [SETUP.md](SETUP.md).

## Credits

- Agent: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent). Model and config behavior follows its providers and configuration docs.
- Android port this started from: [AbuZar-Ansarii/Hermes-Agent-On-Android](https://github.com/AbuZar-Ansarii/Hermes-Agent-On-Android). Original scripts are in `legacy/`.
- Phone-as-user pattern: [AbuZar-Ansarii/Openclaw-phone-control](https://github.com/AbuZar-Ansarii/Openclaw-phone-control), Shizuku plus Termux:API without root.

This repo is a separate optimization for the 9i and is not affiliated with the projects above.
