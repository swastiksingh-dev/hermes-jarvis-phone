# Phone UI rules — Hermes must follow these on every screen task (no-root)

Adapted from the OpenClaw `TOOLS.md`/`AGENTS.md` loop; see `research/openclaw-analysis.md` §6.5.

1. `ui_dump` before every tap. Never guess coordinates from a screenshot alone.
2. Prefer `tap_text "<label>"` over raw `tap X Y`. Raw taps only when the target has no text.
3. Re-dump after every tap/swipe/type. The screen changed; your old bounds are stale.
4. Target absent? `swipe 500 1500 500 500`, re-dump, look again. Max 3 scrolls, then stop and report.
5. Never declare done after a single `launch`. Confirm the expected screen with one more `ui_dump`.
6. One tool per step, keep looping until the task is visibly complete or 10 steps pass.
7. Destructive patterns are refused by `--shell`. If a task needs one, stop and ask the user.
