# lyne reload - Restart QuickShell detached from the terminal

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne reload"
    echo ""
    echo "Kill and restart QuickShell detached from the terminal."
    return 0
fi

quickshell kill
# Wait for it to exit. A shell that Quickshell's crash handler relaunched in
# place doesn't: on kill it aborts and relaunches itself again (Quickshell
# 0.3.2), which left two shells running. SIGKILL skips the crash handler
for _ in {1..10}; do
    pgrep -x quickshell >/dev/null || break
    sleep 0.1
done
pkill -KILL -x quickshell 2>/dev/null
setsid quickshell >/dev/null 2>&1 &
disown
