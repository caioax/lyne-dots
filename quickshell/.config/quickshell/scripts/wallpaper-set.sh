#!/bin/bash
# =============================================================================
# wallpaper-set.sh PATH [TYPE] [SPEED]
# =============================================================================
# Shows PATH as the wallpaper, with the transition chosen in Settings ›
# Wallpaper. Every path that changes the wallpaper goes through here
# (WallpaperService and the boot script), so they all look the same.
#
#   TYPE   none | fade | grow | wipe | wave | random (one of the others)
#   SPEED  fast | normal | slow
#
# Left out (the boot script), both come from wallpaper.transition and
# wallpaper.transitionSpeed in the shell's state.json; fade and normal when
# that has neither.
#
# Images are drawn by awww. Videos (mp4, webm, mkv) play through mpvpaper on
# every output, on the bottom layer so it stays above awww even when
# awww-daemon restarts: awww first shows the video's poster with the
# transition (wallpaper-poster.sh), then mpvpaper starts on top of it.
# Leaving a video, awww takes over the frame on screen before mpvpaper is
# stopped, so nothing jumps back to the poster, and the transition runs from
# there. One video plays at a time; WallpaperService pauses it
# (wallpaper-video.sh) when every screen is covered by a fullscreen window,
# the session is locked or on battery, as set in Settings.
#
# Exits 3 when PATH is not a file, 4 when a video has no poster.
# =============================================================================

path="$1"
type="$2"
speed="$3"

[[ -f "$path" ]] || {
    echo "not found: $path" >&2
    exit 3
}

here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
run="${XDG_RUNTIME_DIR:-/tmp}"
# mpv's IPC socket; it also names our mpvpaper among any others
sock="$run/lyne-wallpaper-video.sock"
frame="$run/lyne-wallpaper-frame.jpg"

state="$HOME/.config/quickshell/state.json"
if [[ -z "$type" || -z "$speed" ]] && [[ -f "$state" ]] && command -v jq >/dev/null; then
    [[ -z "$type" ]] && type="$(jq -r '.wallpaper.transition // empty' "$state" 2>/dev/null)"
    [[ -z "$speed" ]] && speed="$(jq -r '.wallpaper.transitionSpeed // empty' "$state" 2>/dev/null)"
fi

if [[ "$type" == random ]]; then
    kinds=(fade grow wipe wave)
    type="${kinds[RANDOM % ${#kinds[@]}]}"
fi
case "$type" in
    none | fade | grow | wipe | wave) ;;
    *) type=fade ;;
esac

case "$speed" in
    fast) duration=0.6 ;;
    slow) duration=2 ;;
    *) duration=1.2 ;;
esac

is_video() {
    case "${1,,}" in
        *.mp4 | *.webm | *.mkv) return 0 ;;
    esac
    return 1
}

# PID of our mpvpaper, if one runs
video_pid() {
    pgrep -f -- "input-ipc-server=$sock" | head -n 1
}

# The file our mpvpaper plays: the last word of its command line
video_playing() {
    local pid
    pid="$(video_pid)"
    [[ -n "$pid" && -r "/proc/$pid/cmdline" ]] || return 1
    tr '\0' '\n' <"/proc/$pid/cmdline" | tail -n 1
}

# Stops our mpvpaper, leaving the frame it showed on screen through awww
stop_video() {
    local pid
    pid="$(video_pid)"
    [[ -n "$pid" ]] || return 0
    rm -f "$frame"
    "$here/wallpaper-video.sh" screenshot "$frame"
    [[ -s "$frame" ]] && awww img "$frame" --transition-type none
    pkill -f -- "input-ipc-server=$sock"
    for _ in {1..20}; do
        [[ -z "$(video_pid)" ]] && break
        sleep 0.05
    done
    rm -f "$sock"
}

show_image() {
    if [[ "$type" == none ]]; then
        awww img "$1" --transition-type none
    else
        awww img "$1" --transition-type "$type" --transition-duration "$duration" \
            --transition-fps 60 --transition-step 90
    fi
}

# The shell and the boot script may both set one: one change at a time
exec 9>"$run/lyne-wallpaper.lock"
flock -w 15 9

if ! is_video "$path"; then
    stop_video
    show_image "$path"
    exit
fi

real="$(realpath "$path")"
# Already playing (the boot script after a shell reload)
[[ "$(video_playing)" == "$real" ]] && exit 0

poster="$("$here/wallpaper-poster.sh" "$path")" || exit 4

stop_video
# Unless awww already shows it (restored from its cache at login)
if [[ "$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1)" != "$(realpath "$poster")" ]]; then
    show_image "$poster"
    # awww returns before its transition ends: the video starts after it
    [[ "$type" != none ]] && sleep "$duration"
fi

# Without mpvpaper (its AUR build failed) the poster stays
if ! command -v mpvpaper >/dev/null; then
    echo "mpvpaper not installed: showing the poster of $path" >&2
    exit 0
fi

# Detached, so it outlives this script and whoever ran it; without the lock
# fd, or the next change would wait for it forever
setsid -f mpvpaper -l bottom \
    -o "no-audio loop hwdec=auto-safe input-ipc-server=$sock" \
    ALL "$real" >/dev/null 2>&1 </dev/null 9>&-
