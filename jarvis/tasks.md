# Jarvis task inbox — Hermes picks ONE per cycle. Keep small for 4GB.
# How: add `- [ ]` lines. Jarvis marks done with learned facts in memory.py.

## Research (loop-safe, low RAM)
- [ ] Daily tech news digest -> save ~/hermes-9i/logs/research_$(date +%F).md
- [ ] Check 9router dashboard quotas, keep fallback combo healthy (subscription -> cheap -> free)

## Email via phone-as-user (no Gmail API keys needed — uses Shizuku UI control, no-root)
- [ ] Open Gmail app, screenshot inbox, summarize unread (phone/phone-actions.sh gmail + screenshot)
- [ ] Draft reply text to ./draft.txt, wait for user approval before sending

## Apps (Play Store as user)
- [ ] Check update for <pkg> via `phone/phone-actions.sh play <pkg>` + screenshot
- [ ] Download APK only from trusted source via `phone/phone-actions.sh download <url>`, then `install_apk`

## Create
- [ ] Create one useful script/note per day in ~/hermes-9i/creations/
- [ ] Remember every completed task: `python3 ~/hermes-9i/jarvis/memory.py remember "..."`

## Rules for 4GB phone
- One task per cycle, <10 min, <30 lines output. Never run 2 hermes in parallel.
- If battery <20% or hot, do memory-only cycle, skip heavy work.
