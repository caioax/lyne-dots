#!/bin/bash
# =============================================================================
# wallpaper-video.sh pause yes|no
# wallpaper-video.sh screenshot FILE
# =============================================================================
# Talks to the video wallpaper wallpaper-set.sh started, through mpv's IPC
# socket ($XDG_RUNTIME_DIR/lyne-wallpaper-video.sock).
#
#   pause       pauses or resumes it (WallpaperService, after videoRules.js).
#               A player that just started gets up to 3 s to open its socket
#   screenshot  writes the frame on screen to FILE, as a JPEG
#
# Exits 1 when no video wallpaper is playing, 2 on a bad command.
# =============================================================================

sock="${XDG_RUNTIME_DIR:-/tmp}/lyne-wallpaper-video.sock"

# Ours among any other mpvpaper: named by its socket
running() {
    pgrep -f -- "input-ipc-server=$sock" >/dev/null
}

# ipc JSON: one command to mpv, waits for its answer. The socket file can
# show up just before mpv listens on it: a few tries
ipc() {
    for _ in {1..10}; do
        ipc_once "$1" && return 0
        sleep 0.05
    done
    return 1
}

ipc_once() {
    python3 - "$sock" "$1" <<'EOF' 2>/dev/null
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(2)
s.connect(sys.argv[1])
s.sendall(sys.argv[2].encode() + b"\n")
buf = b""
while b'"error"' not in buf:
    data = s.recv(4096)
    if not data:
        break
    buf += data
EOF
}

case "$1" in
    pause)
        case "$2" in
            yes | no) ;;
            *) exit 2 ;;
        esac
        running || exit 1
        for _ in {1..60}; do
            [[ -S "$sock" ]] && break
            sleep 0.05
        done
        ipc '{"command": ["set_property", "pause", '"$([[ "$2" == yes ]] && echo true || echo false)"']}'
        ;;
    screenshot)
        [[ -n "$2" ]] || exit 2
        running || exit 1
        ipc '{"command": ["screenshot-to-file", "'"$2"'", "video"]}'
        ;;
    *)
        echo "usage: wallpaper-video.sh pause yes|no | screenshot FILE" >&2
        exit 2
        ;;
esac
