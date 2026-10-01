# OpenClaw phone-control — primary-source deep dive + gap analysis vs Hermes 9i

> Note (2026-10-01, after this file was written): the router layer described
> below (`router/hermes-9i-router.py`, port 4000, OpenRouter key) was replaced
> by the real 9Router (`decolua/9router`, `npm install -g 9router`,
> `http://127.0.0.1:20128/v1`, dashboard-managed providers). The phone-control
> findings and gap analysis are unaffected.

Scope: only primary sources. No secondary write-ups were used.
Date: 2026-10-01.

## 0. Sources (every claim below cites one of these)

- `[OC-README]` — `https://github.com/AbuZar-Ansarii/Openclaw-phone-control` README
  (`README.md`; repo contains **only** this file — verified via
  `https://api.github.com/repos/AbuZar-Ansarii/Openclaw-phone-control/contents/`,
  which returns a single entry `README.md`). Commit history (8 commits, all
  `Update README.md` / `Initial commit`, 2026-04-04→2026-04-07) confirms no code
  ever lived in this repo.
- `[OC-RAW]` — raw README:
  `https://raw.githubusercontent.com/AbuZar-Ansarii/Openclaw-phone-control/main/README.md`
- `[INSTALLER]` — the actual executable source the README delegates to:
  `https://raw.githubusercontent.com/jarvesusaram99/Openclaw-Termux-NoRoot/main/auto_setup.sh`
  (Step 3 of `[OC-README]` Setup Guide; the repo has since moved to
  `techjarves/Openclaw-Termux-NoRoot` — contents API lists exactly
  `LICENSE`, `README.md`, `auto_setup.sh`). All `auto_setup.sh` citations below
  are to this file's sections: `Step 1/5` (deps), `Step 2/5` (Shizuku/`copy.sh`),
  `Step 3/5` (IPv4 DNS fix), `Step 4/5` (OpenClaw install), `Step 5/5`
  (`phone_control.sh` + `phone_agent.sh` + `IDENTITY.md`/`TOOLS.md`/`AGENTS.md`).
- `[NOROOT-README]` — `https://raw.githubusercontent.com/techjarves/Openclaw-Termux-NoRoot/main/README.md`
  (same project, richer command table + Telegram examples).
- `[HERMES-ANDROID]` — `https://github.com/AbuZar-Ansarii/Hermes-Agent-On-Android`
  (sibling repo: Hermes-on-Termux install + `hermes gateway` + Ollama notes; our
  `legacy/` is copied from it).
- Local repo `D:\hermess-agents-mobile`: `README.md`, `SETUP.md`,
  `hermes-9i-install.sh`, `router/hermes-9i-router.py`, `router/models.txt`,
  `router/start-9router.sh`, `router/.env.example`, `phone/shizuku-bridge.sh`,
  `phone/phone-actions.sh`, `jarvis/jarvis-loop.sh`, `jarvis/memory.py`,
  `jarvis/hermes-config.yaml`, `jarvis/tasks.md`, `termux/boot-autostart.sh`.

Key structural finding: `[OC-README]` is a **pointer repo** (docs + links only).
Its entire control plane lives in `[INSTALLER]` (phone actions, Shizuku
bootstrap, agent doctrine) plus upstream OpenClaw gateway and Ollama. Any parity
work must target `[INSTALLER]` behavior, not `[OC-README]` text.

## 1. Architecture

```
Telegram (any device, NL message)
  → OpenClaw gateway (on-phone daemon, `openclaw gateway`, dashboard :18789)
    → tool `exec`: `bash ~/phone_control.sh <verb> [args]`
      → run_cmd(): rish → adb → su   (first available wins)
        → Android shell (screencap / am / input / svc / dumpsys / uiautomator …)
    → Ollama model (`ollama serve` + `ollama run minimax-m2.7:cloud`) reasons
      over text output; sees screen via `ui-dump` (parsed XML bounds), not pixels
```

- `[OC-README]` Key Features section: Telegram integration, Ollama local brain,
  "30+ System Actions", Shizuku rootless bridge, one-line setup.
- `[OC-README]` Prerequisites table: Android 11+, Termux **F-Droid**
  (Play version "outdated and will cause installation errors"), Shizuku,
  Telegram Bot Token from `@BotFather`.
- `[NOROOT-README]` credits the gateway to
  `AidanPark/openclaw-android` ("The AI gateway that powers this project"),
  Shizuku (`RikkaApps/Shizuku`), Termux, Google Gemini.
- Agent doctrine is files, not code: `[INSTALLER]` Step 5/5 writes
  `~/.openclaw/workspace/IDENTITY.md` (PhoneBot persona, "MUST NEVER refuse …
  UI navigation"), `TOOLS.md` (the ui-dump→tap loop + command catalog +
  worked Settings→Dark Mode example), `AGENTS.md` ("DO NOT STOP AFTER ONE TOOL
  CALL … loop exec until 100%"), plus a stub `~/phone_agent.sh` ("Vision Agent
  initialized … take a screenshot, analyze it, issue UI commands").
- Hermes 9i architecture for contrast (`README.md:34-48`, `SETUP.md`):
  two Termux sessions — Session 1 = stdlib OpenRouter proxy
  (`router/hermes-9i-router.py:1-117`, `~30MB`, `127.0.0.1:4000`, fallback chain
  in `router/models.txt:4-8`), Session 2 = Hermes CLI pointed at it
  (`jarvis/hermes-config.yaml:3-8`, `provider: custom`), timed loop
  (`jarvis/jarvis-loop.sh:7-31`, 1 task/5 min, battery guard), SQLite memory
  (`jarvis/memory.py:1-38`, 5000-row cap, LIKE recall).

## 2. Control plane: Shizuku / rish vs adb vs Termux:API, per action

### 2.1 Transport selection

- OpenClaw `[INSTALLER]` Step 5/5 `run_cmd()`:
  `rish` first, else `adb` (only if `adb get-state` succeeds), else `su`,
  else `❌ Error: Start Shizuku first`, exit 1. So priority is
  **rish > adb > su**, with su as a last resort (ours never uses su —
  `phone/shizuku-bridge.sh:15-20` is `rish → adb`, comment "Never su").
- Shizuku bootstrap `[INSTALLER]` Step 2/5 (embedded `copy.sh` written to
  `~/storage/shared/Shizuku/copy.sh`): `termux-setup-storage`; writes
  `$PREFIX/bin/shizuku` (scans `nmap -sT -p30000-50000 localhost`, `adb connect
  localhost:$port`, launches Shizuku via `pm path … libshizuku.so`, then
  `settings put global adb_wifi_enabled 0`) and `$PREFIX/bin/rish`
  (`/system/bin/app_process … rikka.shizuku.shell.ShizukuShellLoader`,
  `RISH_APPLICATION_ID=com.termux`); copies `rish_shizuku.dex` to `~` and
  `chmod -w` it (app_process refuses writable dex). Fails fast with
  re-export instructions if `rish_shizuku.dex` is missing. Arch-aware
  (`arm64/arm/x86_64/x86` via `getprop ro.product.cpu.abi`).
- Pairing/start/export `[OC-README]` Step 1 (4 sub-steps): Developer Options
  (7× Build Number) → Wireless debugging ON → Shizuku Pairing (code) → Start →
  "Use Shizuku in terminal apps" → Export files into a folder named exactly
  `Shizuku`. Troubleshooting: disable battery optimization; folder name is
  case-sensitive; Ollama needs 2–4 GB free RAM.
- Hermes transport (`phone/shizuku-bridge.sh:15-20`): `rish -c` first, plain
  `adb shell` second, hard error otherwise. Same pairing/start/export steps in
  `SETUP.md:11-19` (plus `termux-setup-storage`, Unrestricted battery).
- Termux:API usage: OpenClaw uses **almost none** — the only on-device API
  outside adb-shell is `node -e` XML parsing inside `ui-dump` (Node.js from
  Step 1/5 deps, not Termux:API). Hermes instead leans heavily on Termux:API:
  `termux-torch`, `termux-volume`, `termux-notification`, `termux-vibrate`,
  `termux-tts-speak`, `termux-battery-status`, `termux-location`,
  `termux-contact-list`, `termux-sms-list/send`, `termux-telephony-call`,
  `termux-download/share`, `termux-clipboard-*` (`phone/phone-actions.sh:10-34`).

### 2.2 Per-action implementation (OpenClaw `phone_control.sh`, `[INSTALLER]` Step 5/5)

All via `run_cmd` → rish/adb shell unless noted. `shell` runs **arbitrary**
commands, so anything adb-expressible is reachable even without a named verb.

| # | OpenClaw verb | Exact implementation | Transport | Hermes 9i parity |
|---|---|---|---|---|
| 1 | `screenshot [path]` | `screencap -p '${1:-/sdcard/screenshot.png}'` | rish/adb | ✅ `shizuku-bridge.sh:32` (`screencap -p /sdcard/hermes_shot.png` + `cp`, Termux fallback) via `phone-actions.sh:12` |
| 2 | `open-app <pkg>` | `monkey -p $1 -c android.intent.category.LAUNCHER 1` | rish/adb | ✅ `--launch` (`shizuku-bridge.sh:29`) via `launch` (`phone-actions.sh:25`) |
| 3 | `open-url <url>` | `am start -a android.intent.action.VIEW -d '$1'` | rish/adb | ✅ `--open-url` (`shizuku-bridge.sh:30`) via `open_url` (`phone-actions.sh:22`) |
| 4 | `youtube-search <q>` | spaces→`+`, `am start -a VIEW -d 'https://www.youtube.com/results?search_query=$QUERY' com.google.android.youtube` | rish/adb | ❌ **missing** — only generic `open_url`; no app-scoped search verb |
| 5 | `wifi on/off` | `svc wifi enable/disable` | rish/adb | ✅ `--wifi` (`shizuku-bridge.sh:34`) via `wifi_on/off` (`phone-actions.sh:8`) |
| 6 | `battery` | `dumpsys battery \| grep level` | rish/adb | ✅ partial — richer `termux-battery-status` (`phone-actions.sh:16`); no raw `dumpsys` level verb |
| 7 | `tap X Y` | `input tap X Y` | rish/adb | ✅ `--tap` (`shizuku-bridge.sh:39`) via `tap` (`phone-actions.sh:26`) |
| 8 | `swipe X1 Y1 X2 Y2 [ms]` | `input swipe … ${5:-500}` | rish/adb | ✅ `--swipe` (default 300 ms, `shizuku-bridge.sh:39`) via `swipe` (`phone-actions.sh:27`) |
| 9 | `text <str>` | `input text '$*'` | rish/adb | ✅ `--input-text` (space→`%s`, `shizuku-bridge.sh:37`) via `type` (`phone-actions.sh:29`) |
| 10 | `key <code>` | `input keyevent <code>` | rish/adb | ✅ `--key` (`shizuku-bridge.sh:40`); named: home(3)/back(4)/power(26) (`phone-actions.sh:28`) |
| 11 | `home` / `back` | `input keyevent 3` / `4` | rish/adb | ✅ `key_home`/`key_back` |
| 12 | `recent` | `input keyevent 187` | rish/adb | ❌ **missing** (no recents verb/flag) |
| 13 | `power` | `input keyevent 26` | rish/adb | ✅ `key_power` |
| 14 | `volume-up/down` | `input keyevent 24` / `25` | rish/adb | ⚠️ partial — `termux-volume music 15/3` (`phone-actions.sh:11`); no keyevent 24/25, no mute |
| 15 | `screenon` | `input keyevent 224` (wake) | rish/adb | ❌ **missing** |
| 16 | `ui-dump` | `uiautomator dump /sdcard/window_dump.xml` + `node -e` regex over `text\|content-desc` + `bounds` → `[x1,y1][x2,y2] label` lines | rish/adb + Node | ❌ **missing — biggest gap** (we screenshot but never parse UI hierarchy) |
| 17 | `shell <cmd>` | arbitrary `run_cmd "$*"` | rish/adb(/su) | ❌ **missing as generic verb** — `--intent` (`shizuku-bridge.sh:31`) covers only `am start`; no arbitrary-shell action in `phone-actions.sh` |
| 18 | `brightness/mute/lock/kill-app/list-apps/send-sms/whatsapp-send/info/call/bluetooth` | **not in `phone_control.sh`** — documented in `[NOROOT-README]` Commands table only; reachable in practice via `shell` + `openclaw onboard` Gemini agent composing adb commands | (via `shell`) | ⚠️ mixed — Hermes natively has `bt_on/off`, `call`, `sms_inbox/send`, richer volume/battery; lacks `brightness`, `mute`, `lock`, `kill-app`, `list-apps`, `whatsapp-send`, `info` |

Net: 15/17 named verbs overlap; Hermes's Termux:API surface (torch, notify,
vibrate, tts, location, contacts, sms, clipboard, download/share, gmail/play
intents, notif-dump) is **wider** than OpenClaw's, but OpenClaw's three
force-multipliers — `ui-dump`, `shell`, and the `TOOLS.md`/`AGENTS.md` tap-loop
doctrine — are absent here.

## 3. Setup flow (OpenClaw, end to end)

1. Shizuku prep `[OC-README]` Step 1: Build Number ×7 → Wireless debugging ON →
   Pairing (code) → Start → Export files to `Shizuku/` (see §2.1).
2. Ollama `[OC-README]` Step 2 (two Termux sessions):
   `pkg install ollama` → `ollama serve`, then `ollama run minimax-m2.7:cloud`.
   (`[HERMES-ANDROID]` Ollama section shows the sibling variant
   `ollama run gemma4:31b-cloud`; `[NOROOT-README]` instead uses a Gemini API
   key — the brain is swappable, the phone-control layer is not.)
3. One-line installer `[OC-README]` Step 3 → `[INSTALLER]` Steps 1–5/5:
   deps (`curl nodejs git cmake make clang binutils nmap openssl android-tools
   which`, explicit `curl/node/git/nmap/adb` presence check, no `set -e`);
   Shizuku link (`copy.sh`, §2.1); `NODE_OPTIONS=--dns-result-order=ipv4first`
   appended to `~/.bashrc` (Termux IPv4 DNS fix); official OpenClaw via
   `bash -c "$(curl -sSL https://myopenclawhub.com/install)"` (skipped if
   `openclaw` or `~/.openclaw/repo` exists); writes `phone_control.sh`,
   `phone_agent.sh`, `IDENTITY.md`/`TOOLS.md`/`AGENTS.md`.
4. Credentials `[OC-README]` Configuration: `openclaw onboard` (links Telegram
   bot token), `openclaw auth add google --key …` (Gemini variant,
   `[INSTALLER]` closing banner).
5. Hermes 9i flow for contrast (`SETUP.md:21-55`, `hermes-9i-install.sh:15-53`):
   one curl-piped installer (minimal `python git curl termux-api jq openssh` +
   conditional `clang libffi openssl pkg-config make`, Python 3.13 psutil
   `_sysconfigdata` patch, shallow `hermes-agent` clone, `pip install -e
   '.[termux]'`, `~/hermes-9i/` layout) → Session 1 router
   (`router/start-9router.sh:6-18`, key saved `0600` to
   `~/.hermes-9i-router-key`, `ROUTER_MODELS`/`ROUTER_PORT` overrides) →
   Session 2 `hermes setup` (custom endpoint `http://127.0.0.1:4000/v1`,
   `provider: custom`) → `--check` + `--once` verification. Deliberately **no
   proot/Ollama** (OOM on 4 GB — `SETUP.md:30`, `README.md:52`).

## 4. Telegram / gateway flow

- Onboard: `openclaw onboard` links the `@BotFather` token
  (`[OC-README]` Configuration §1; `[NOROOT-README]` Step 4). Prereq row:
  "Telegram Bot Token / @BotFather" (`[OC-README]` Prerequisites table).
- Token: `cat ~/.openclaw/openclaw.json` (`[OC-README]` §2) — the gateway token
  the dashboard asks for.
- Daemon: `openclaw gateway --verbose` (debug/logs) or `openclaw gateway`
  (`[OC-README]` §3). Dashboard `http://127.0.0.1:18789`, paste token → Connect
  (`[OC-README]` §4).
- Runtime path (`[NOROOT-README]` Step 5 examples: "What's my battery?",
  "Open Chrome", "Search YouTube for lofi beats", "Turn off WiFi"): Telegram NL
  → gateway → model (Ollama `minimax-m2.7:cloud` per `[OC-README]` Step 2, or
  Gemini per `[NOROOT-README]`) → `exec` of `phone_control.sh` verbs, looping
  `ui-dump → tap/swipe/text` per `TOOLS.md`/`AGENTS.md` until done.
- Hermes 9i has **no remote trigger and no daemon**: interaction is local
  `hermes` CLI (`[HERMES-ANDROID]` command table: `hermes`, `hermes setup`,
  `hermes gateway`, direct-prompt/file/model flags, `!` shell, `-o` save) plus
  the 5-minute poll loop (`jarvis/jarvis-loop.sh:29-31`, `termux-wake-lock`,
  `CYCLE_MIN`, boot reinstall via `termux/boot-autostart.sh:6-14`). Nothing
  listens on a port except the localhost-only router
  (`router/hermes-9i-router.py:117`, `127.0.0.1`).

## 5. Full action inventory table (OpenClaw × Hermes 9i)

Legend: ✅ present · ⚠️ partial · ❌ missing. "Hermes impl" cites our file:line.

| Capability | OpenClaw (`phone_control.sh` / docs) | Transport | Hermes 9i | Hermes impl |
|---|---|---|---|---|
| screenshot | `screencap -p` | rish/adb | ✅ | `phone-actions.sh:12` + `shizuku-bridge.sh:32` |
| open app | `monkey -p … LAUNCHER 1` | rish/adb | ✅ | `phone-actions.sh:25`, `shizuku-bridge.sh:29` |
| open URL / intent | `am start -a VIEW -d` | rish/adb | ✅ +more | `phone-actions.sh:22`, `--intent` raw `am` (`shizuku-bridge.sh:31`) |
| youtube search | app-scoped `am start … youtube results` | rish/adb | ❌ | — |
| wifi toggle | `svc wifi` | rish/adb | ✅ | `phone-actions.sh:8`, `shizuku-bridge.sh:34` |
| bluetooth toggle | docs table only (via `shell`) | via `shell` | ✅ (better: direct verb) | `phone-actions.sh:9`, `--bt` (`shizuku-bridge.sh:35`) |
| battery | `dumpsys battery \| grep level` | rish/adb | ⚠️ (richer API, no dumpsys verb) | `phone-actions.sh:16` |
| tap / swipe | `input tap/swipe` | rish/adb | ✅ | `phone-actions.sh:26-27`, `shizuku-bridge.sh:39` |
| type text | `input text` | rish/adb | ✅ (better: `%s` escaping) | `phone-actions.sh:29`, `shizuku-bridge.sh:37` |
| keyevent (generic) | `key <code>` | rish/adb | ✅ | `shizuku-bridge.sh:40` |
| home / back / power | keyevents 3/4/26 | rish/adb | ✅ | `phone-actions.sh:28` |
| recents | keyevent 187 | rish/adb | ❌ | — |
| wake (`screenon`) | keyevent 224 | rish/adb | ❌ | — |
| volume | keyevents 24/25 | rish/adb | ⚠️ (Termux:API levels only) | `phone-actions.sh:11` |
| **ui-dump (see screen as text+bounds)** | `uiautomator dump` + node parse | rish/adb + node | ❌ | — |
| **arbitrary shell** | `shell <cmd>` passthrough | rish/adb/su | ❌ (`--intent` is `am`-only) | `shizuku-bridge.sh:31` (partial) |
| gmail / play / launch / install_apk / notif-dump | — (composable via `shell`) | — | ✅ (direct verbs) | `phone-actions.sh:23-24,30`, `shizuku-bridge.sh:33,41-43` |
| torch / notify / vibrate / tts / location / contacts / sms / call / clipboard / download / share | — | — | ✅ (Termux:API only here) | `phone-actions.sh:10,13-21,31-34` |
| brightness / mute / lock / kill-app / list-apps / whatsapp-send / device-info | docs table / `shell`-composable | via `shell` | ❌ | — |
| remote trigger (Telegram) + gateway daemon + dashboard | `onboard` / `gateway` / `:18789` | — | ❌ (local CLI + poll loop only) | `jarvis-loop.sh`, `boot-autostart.sh` |
| agent tap-loop doctrine | `IDENTITY.md`/`TOOLS.md`/`AGENTS.md` | — | ❌ (`tasks.md` inbox has no UI-grounding rules) | `jarvis/tasks.md:20-22` |

## 6. Gap analysis vs our Hermes 9i repo (ordered by impact)

1. **`ui-dump` screen grounding — the load-bearing gap.** OpenClaw's autonomy
   comes from `uiautomator dump` + node bounds parsing (`[INSTALLER]` Step 5/5
   `ui-dump` branch) feeding the `TOOLS.md` see-then-tap loop. Hermes can
   screenshot (`shizuku-bridge.sh:32`) but never extracts clickable
   text/bounds, so `tap`/`swipe` coordinates are guesses. Without this, every
   other phone verb stays半-blind.
2. **No generic `shell` passthrough.** OpenClaw `shell` runs any adb command
   (`[INSTALLER]` Step 5/5 `shell)` branch); ours restricts to `am start`
   (`shizuku-bridge.sh:31`) plus fixed verbs. bluetooth-on-OpenClaw,
   brightness, kill-app, list-apps, dumpsys deep-dives all ride on `shell`.
3. **No remote trigger / gateway.** Telegram→gateway→exec (`[OC-README]`
   Configuration §§1–4; `[NOROOT-README]` Step 5) vs. Hermes's local-only loop
   (`jarvis-loop.sh:29-31`). Phone-as-user is far less useful when you must be
   on the phone to ask.
4. **Small verb gaps: `youtube-search`, `recent` (187), `screenon` (224),
   keyevent volume/mute, `brightness`, `lock`, `kill-app`, `list-apps`,
   `whatsapp-send`, `info`.** Each is one `input`/`am`/`dumpsys` line (patterns
   in `[INSTALLER]` Step 5/5); `youtube-search` is the only one with
   non-obvious syntax worth copying verbatim.
5. **No agent UI-navigation doctrine.** `IDENTITY.md`/`TOOLS.md`/`AGENTS.md`
   (`[INSTALLER]` Step 5/5 heredocs) force the see→tap→re-dump loop and forbid
   one-shot stops; our `jarvis/tasks.md:20-22` rules cover cycle hygiene
   (one task, battery guard) but say nothing about grounding taps in
   observations.
6. **Shizuku bootstrap fragility.** `[INSTALLER]` Step 2/5 `copy.sh`
   regenerates `rish`/`shizuku` from the exported dex, reconnects over the
   30000–50000 port scan, and errors with exact re-export steps; ours assumes
   `rish` exists (`shizuku-bridge.sh:14-20`, `SETUP.md:84-86` troubleshooting
   only). No port-scan reconnect, no dex check.
7. **Installer robustness.** `[INSTALLER]` avoids `set -e`, verifies
   `curl/node/git/nmap/adb` explicitly, applies the Termux IPv4 DNS fix
   (`Step 3/5`, `~/.bashrc`); ours uses `set -euo pipefail`
   (`hermes-9i-install.sh:5`) with no equivalent reconnect/DNS hardening.
8. **Ollama path documented upstream, rejected here — deliberately.**
   `[OC-README]` Step 2 + Troubleshooting (2–4 GB RAM) vs. our explicit no-proot
   no-Ollama stance (`SETUP.md:30`, `README.md:52`). Not a gap to close on 4 GB;
   record as an intentional divergence (cloud `:free` via 9Router instead of
   on-device inference).

## 7. Recommended additions (priority order)

- **P0 — `ui-dump` flag + parsed-bounds action.** Add `--ui-dump` to
  `phone/shizuku-bridge.sh` (`uiautomator dump /sdcard/window_dump.xml`, copy
  to out-path like `--screenshot` does at `shizuku-bridge.sh:32`) plus a
  `ui_dump` action in `phone/phone-actions.sh`; parse with python3-stdlib
  regex (no node dep — our router philosophy is stdlib-only,
  `router/hermes-9i-router.py:8`) emitting `[x1,y1][x2,y2] label` lines exactly
  like `[INSTALLER]`'s node snippet. Add a `tap_text <label>` helper that
  centers bounds → `--tap`. This single addition unlocks grounded autonomy.
- **P0 — generic `shell` action (guardrailed).** Add `--shell` passthrough in
  the bridge + `shell` action in `phone-actions.sh`, mirroring `[INSTALLER]`
  `shell)` but restricted to our `rish→adb` chain (never su, per
  `shizuku-bridge.sh:16` comment). Covers brightness/kill-app/list-apps/info
  without a verb explosion; document a denylist (no `rm -rf /sdcard`-class
  writes) in `SETUP.md` troubleshooting table (`SETUP.md:81-92`).
- **P1 — close the small verb gaps in one pass.** `youtube_search`
  (copy `[INSTALLER]` URL-encoding verbatim), `recent` (187), `screenon`
  (224), `volume_key_up/down` + `mute`, `brightness`, `lock`, `kill_app`,
  `list_apps`, `whatsapp_send`, `device_info` — each one line in both files
  following the existing `case` style (`phone-actions.sh:7-34`,
  `shizuku-bridge.sh:28-43`). Update the `phone-actions.sh` usage line and
  `SETUP.md:62-64` action count.
- **P1 — UI-grounding doctrine for the loop.** Extend `jarvis/tasks.md` (or a
  new `jarvis/phone-rules.md` referenced from the loop prompt at
  `jarvis-loop.sh:19`) with the `TOOLS.md` loop: `ui_dump` before every tap,
  re-dump after, swipe `500,1500→500,500` when target absent, never declare
  done after a single `launch` — adapted from `[INSTALLER]` `TOOLS.md` +
  `AGENTS.md`. Cheap, no code.
- **P2 — Shizuku self-heal.** Port the reconnect core of `[INSTALLER]`
  `copy.sh`: `--repair` flag that re-links `rish` from
  `~/storage/shared/Shizuku/rish_shizuku.dex` (arch-aware dex path), plus a
  `--reconnect` port-scan (`nmap -sT -p30000-50000 localhost` → `adb connect`)
  before failing in `adb_shell`. Keep our `rish→adb` order; do not add `su`.
- **P2 — remote trigger (lightweight, no gateway dependency).** Telegram
  long-poll via `termux-notification`/`bash` is heavy; smallest useful slice:
  poll `tasks.md` inbox from an accessible channel (e.g. a watched file/URL
  the loop already reads at `jarvis-loop.sh:19`). Full `openclaw gateway`
  parity (`[OC-README]` §§1–4) is explicitly deferred — it needs Node + token
  plumbing our 4 GB budget doesn't have.
- **P3 — installer hardening.** Borrow `[INSTALLER]` Steps 1/5+3/5: explicit
  critical-command check (fail with the exact `pkg install` line instead of
  dying under `set -euo pipefail`), `NODE_OPTIONS=--dns-result-order=ipv4first`
  export in `start-9router.sh` (our router hits network-dependent OpenRouter,
  `hermes-9i-router.py:18`), keep everything else as-is.
- **Explicitly not recommended:** on-device Ollama (`[OC-README]` Step 2),
  `su` fallback (`[INSTALLER]` `run_cmd`), Node.js XML parsing (use stdlib
  python), Play-Store Termux (both repos agree: F-Droid only).
