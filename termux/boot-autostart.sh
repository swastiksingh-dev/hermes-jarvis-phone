#!/data/data/com.termux/files/usr/bin/bash
# Always-on helpers for 9i. Run once.
# 1. Disable battery kill: Settings > Apps > Termux + Shizuku > Battery > Unrestricted (manual)
# 2. Termux:Boot autostart (needs Termux:Boot apk): this file goes to ~/.termux/boot/
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/jarvis-start.sh <<'B'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
# router in background (Session 1 equivalent after reboot)
nohup bash $HOME/hermes-9i/router/start-9router.sh > $HOME/hermes-9i/logs/router.log 2>&1 &
# jarvis loop in background
nohup bash $HOME/hermes-9i/jarvis/jarvis-loop.sh > $HOME/hermes-9i/logs/jarvis.log 2>&1 &
B
chmod +x ~/.termux/boot/jarvis-start.sh
echo "boot script installed. Also manually: termux-wake-lock; pkg install termux-boot (apk from F-Droid)"
