#!/bin/bash
# =============================================================================
# wallpaper-video.sh pause yes|no
# wallpaper-video.sh screenshot FILE
# wallpaper-video.sh fps N
# =============================================================================
# Talks to the video wallpaper wallpaper-set.sh started, through mpv's IPC
# socket ($XDG_RUNTIME_DIR/lyne-wallpaper-video.sock).
#
#   pause       pauses or resumes it (WallpaperService, after videoRules.js).
#               A player that just started gets up to 3 s to open its socket
#   screenshot  writes the frame on screen to FILE, as a JPEG
#   fps         caps the frame rate at N (0: the video's own). Only a video
#               faster than N drops frames; a slower one keeps its rate.
#               Fewer frames, less work for Hyprland redrawing the screens
#
# Exits 1 when no video wallpaper is playing, 2 on a bad command.
# =============================================================================

sock="${XDG_RUNTIME_DIR:-/tmp}/lyne-wallpaper-video.sock"

# Ours among any other mpvpaper: named by its socket
running() {
    pgrep -f -- "input-ipc-server=$sock" >/dev/null
}

# Waits for a player that just started to open its socket
wait_socket() {
    for _ in {1..60}; do
        [[ -S "$sock" ]] && break
        sleep 0.05
    done
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

# Prints mpv's answer (the line with "error")
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
for line in buf.decode().splitlines():
    if '"error"' in line:
        print(line)
EOF
}

case "$1" in
    pause)
        case "$2" in
            yes | no) ;;
            *) exit 2 ;;
        esac
        running || exit 1
        wait_socket
        ipc '{"command": ["set_property", "pause", '"$([[ "$2" == yes ]] && echo true || echo false)"']}' >/dev/null
        ;;
    screenshot)
        [[ -n "$2" ]] || exit 2
        running || exit 1
        ipc '{"command": ["screenshot-to-file", "'"$2"'", "video"]}' >/dev/null
        ;;
    fps)
        [[ "$2" =~ ^[0-9]+$ ]] || exit 2
        running || exit 1
        wait_socket
        filter=""
        if ((10#$2 > 0)); then
            rate="$(ipc '{"command": ["get_property", "container-fps"]}' |
                python3 -c 'import json, sys; print(json.loads(sys.stdin.read()).get("data") or 0)' 2>/dev/null)"
            # Above N by more than rounding (29.97 stays under a cap of 30)
            python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > int(sys.argv[2]) + 0.5 else 1)' \
                "${rate:-0}" "$2" 2>/dev/null && filter="fps=$((10#$2))"
        fi
        ipc '{"command": ["set_property", "vf", "'"$filter"'"]}' >/dev/null
        ;;
    *)
        echo "usage: wallpaper-video.sh pause yes|no | screenshot FILE | fps N" >&2
        exit 2
        ;;
esac
