#!/usr/bin/env bats
# scripts/wallpaper-set.sh (the transition of every wallpaper change), the
# poster of videos (wallpaper-poster.sh), the pause of a video
# (wallpaper-video.sh) and the boot script, with stand-ins for awww, ffmpeg
# and mpvpaper

load helpers

setup() {
    lyne_setup
    SCRIPT="$REPO/quickshell/.config/quickshell/scripts/wallpaper-set.sh"
    VIDEO="${LYNE_TEST_SHELL:-$REPO/quickshell/.config/quickshell}/scripts/wallpaper-video.sh"
    BOOT="$REPO/local/.local/scripts/Wallpaper/wallpaper-boot.sh"
    STATE="$HOME/.config/quickshell/state.json"
    WALL="$HOME/.local/wallpapers/a.jpg"
    mkdir -p "$HOME/.local/wallpapers" "$HOME/.config/quickshell" "$BATS_TEST_TMPDIR/bin"
    printf 'img' >"$WALL"
    # The boot script finds it through the stow link
    ln -s "$REPO/quickshell/.config/quickshell/scripts" "$HOME/.config/quickshell/scripts"
    # awww: logs `img` calls; `query` answers with $AWWW_SHOWS
    cat >"$BATS_TEST_TMPDIR/bin/awww" <<'EOF'
#!/bin/bash
case "$1" in
    query) [[ -n "$AWWW_SHOWS" ]] && echo "eDP-1: 1920x1080, scale: 1, currently displaying: image: $AWWW_SHOWS"; exit 0 ;;
    *) echo "awww $*" >>"$STUB_LOG" ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/awww"
    # ffmpeg: writes a poster to its last argument, fails on a "broken" file
    cat >"$BATS_TEST_TMPDIR/bin/ffmpeg" <<'EOF'
#!/bin/bash
for a; do :; done
[[ "$*" == *broken* ]] && exit 1
echo "ffmpeg $*" >>"$STUB_LOG"
printf 'poster' >"$a"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/ffmpeg"
    # mpvpaper: logs its arguments, answers mpv's IPC on its socket and
    # writes a frame for screenshot-to-file
    cat >"$BATS_TEST_TMPDIR/bin/mpvpaper" <<'EOF'
#!/usr/bin/env python3
import json, os, re, socket, sys
with open(os.environ["STUB_LOG"], "a") as log:
    log.write("mpvpaper " + " ".join(sys.argv[1:]) + "\n")
path = re.search(r"input-ipc-server=(\S+)", " ".join(sys.argv)).group(1)
srv = socket.socket(socket.AF_UNIX)
srv.bind(path)
srv.listen()
while True:
    conn, _ = srv.accept()
    cmd = json.loads(conn.makefile().readline())["command"]
    with open(os.environ["STUB_LOG"], "a") as log:
        log.write("ipc " + " ".join(json.dumps(c) if isinstance(c, bool) else str(c) for c in cmd) + "\n")
    if cmd[0] == "screenshot-to-file":
        open(cmd[1], "w").write("frame")
    if cmd[:2] == ["get_property", "container-fps"]:
        conn.sendall(json.dumps({"data": float(os.environ.get("VIDEO_FPS", "30")), "error": "success"}).encode() + b"\n")
    else:
        conn.sendall(b'{"error": "success"}\n')
    conn.close()
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/mpvpaper"
    # The real pgrep (the suite's stand-in sees nothing): every pattern here
    # names the test's own socket
    ln -s "$(PATH=/usr/bin:/bin command -v pgrep)" "$BATS_TEST_TMPDIR/bin/pgrep"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    # The socket, lock and frame: never the session's
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
    mkdir -p "$XDG_RUNTIME_DIR"
    SOCK="$XDG_RUNTIME_DIR/lyne-wallpaper-video.sock"
    FRAME="$XDG_RUNTIME_DIR/lyne-wallpaper-frame.jpg"
    VID="$HOME/.local/wallpapers/clip.mp4"
    printf 'video' >"$VID"
}

teardown() {
    pkill -f -- "input-ipc-server=$SOCK" || true
}

# PIDs of the stand-in mpvpaper
players() {
    pgrep -f -- "input-ipc-server=$SOCK"
}

# The poster wallpaper-poster.sh made for $1
poster_of() {
    # LYNE_TEST_SHELL: a copy of the shell (to sabotage the script)
    "${LYNE_TEST_SHELL:-$REPO/quickshell/.config/quickshell}/scripts/wallpaper-poster.sh" "$1"
}

# Waits for the detached mpvpaper's socket
wait_player() {
    for _ in {1..40}; do
        [[ -S "$SOCK" ]] && return 0
        sleep 0.05
    done
    return 1
}

@test "type and speed from the arguments" {
    run "$SCRIPT" "$WALL" grow slow
    assert_success
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type grow --transition-duration 2 --transition-fps 60 --transition-step 90"
    : >"$STUB_LOG"
    run "$SCRIPT" "$WALL" wipe fast
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type wipe --transition-duration 0.6 --transition-fps 60 --transition-step 90"
}

@test "none: shown at once, no duration" {
    run "$SCRIPT" "$WALL" none slow
    assert_success
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type none"
}

@test "random: one of the others, at the chosen speed" {
    for _ in {1..40}; do
        run "$SCRIPT" "$WALL" random normal
        assert_success
    done
    run grep -cvE -- '--transition-type (fade|grow|wipe|wave) --transition-duration 1.2 ' "$STUB_LOG"
    assert_output 0
}

@test "no arguments: read from state.json, fade and normal without it" {
    run "$SCRIPT" "$WALL"
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type fade --transition-duration 1.2 --transition-fps 60 --transition-step 90"
    : >"$STUB_LOG"
    echo '{"wallpaper": {"transition": "wave", "transitionSpeed": "fast"}}' >"$STATE"
    run "$SCRIPT" "$WALL"
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type wave --transition-duration 0.6 --transition-fps 60 --transition-step 90"
}

@test "unknown values fall back to fade and normal" {
    run "$SCRIPT" "$WALL" center glacial
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type fade --transition-duration 1.2 --transition-fps 60 --transition-step 90"
}

@test "missing file: exit 3, nothing shown" {
    run "$SCRIPT" "$HOME/nope.jpg" fade normal
    assert_failure 3
    assert_output --partial "not found"
    assert_equal "$(cat "$STUB_LOG")" ""
}

@test "boot: the saved wallpaper with the transition from the state" {
    echo "$WALL" >"$HOME/.local/wallpapers/.current"
    echo '{"wallpaper": {"transition": "grow", "transitionSpeed": "slow"}}' >"$STATE"
    run "$BOOT"
    assert_success
    assert_equal "$(cat "$STUB_LOG")" "awww img $WALL --transition-type grow --transition-duration 2 --transition-fps 60 --transition-step 90"
}

@test "boot: already on screen, nothing to do" {
    echo "$WALL" >"$HOME/.local/wallpapers/.current"
    AWWW_SHOWS="$(realpath "$WALL")" run "$BOOT"
    assert_success
    assert_equal "$(cat "$STUB_LOG")" ""
}

@test "video: awww shows the poster, then mpvpaper plays it on every output" {
    run "$SCRIPT" "$VID" fade fast
    assert_success
    wait_player
    poster="$(poster_of "$VID")"
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 1
    assert_equal "$(grep '^awww' "$STUB_LOG")" "awww img $poster --transition-type fade --transition-duration 0.6 --transition-fps 60 --transition-step 90"
    assert_equal "$(grep '^mpvpaper' "$STUB_LOG")" "mpvpaper -l bottom -o no-audio loop hwdec=auto-safe input-ipc-server=$SOCK ALL $(realpath "$VID")"
    assert_equal "$(players | wc -l)" 1
}

@test "video already playing: nothing again" {
    "$SCRIPT" "$VID" none
    wait_player
    : >"$STUB_LOG"
    run "$SCRIPT" "$VID" none
    assert_success
    assert_equal "$(cat "$STUB_LOG")" ""
    assert_equal "$(players | wc -l)" 1
}

@test "video to image: the frame on screen stays while the image comes in" {
    "$SCRIPT" "$VID" none
    wait_player
    : >"$STUB_LOG"
    run "$SCRIPT" "$WALL" wipe fast
    assert_success
    assert_equal "$(cat "$STUB_LOG")" "ipc screenshot-to-file $FRAME video
awww img $FRAME --transition-type none
awww img $WALL --transition-type wipe --transition-duration 0.6 --transition-fps 60 --transition-step 90"
    assert_equal "$(players | wc -l)" 0
    [[ ! -e "$SOCK" ]]
}

@test "video to video: one player, on the new one" {
    other="$HOME/.local/wallpapers/other.webm"
    printf 'other' >"$other"
    "$SCRIPT" "$VID" none
    wait_player
    : >"$STUB_LOG"
    run "$SCRIPT" "$other" none
    assert_success
    sleep 0.3
    wait_player
    assert_equal "$(players | wc -l)" 1
    # The poster is made before the old player stops
    assert_equal "$(grep -v '^mpvpaper' "$STUB_LOG" | cut -d' ' -f1-3)" "ffmpeg -nostdin -loglevel
ipc screenshot-to-file $FRAME
awww img $FRAME
awww img $(poster_of "$other")"
    assert_equal "$(grep '^mpvpaper' "$STUB_LOG" | awk '{print $NF}')" "$(realpath "$other")"
}

@test "video whose poster awww already shows (login): only the player starts" {
    poster="$(poster_of "$VID")"
    : >"$STUB_LOG"
    AWWW_SHOWS="$poster" run "$SCRIPT" "$VID" fade slow
    assert_success
    wait_player
    run grep -c '^awww\|^ffmpeg' "$STUB_LOG"
    assert_output 0
    assert_equal "$(players | wc -l)" 1
}

@test "poster: made once, made again when the video changes" {
    first="$(poster_of "$VID")"
    assert_equal "$(poster_of "$VID")" "$first"
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 1
    printf 'longer video' >"$VID"
    touch -d '1 hour ago' "$VID"
    second="$(poster_of "$VID")"
    [[ "$second" != "$first" && -s "$second" ]]
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 2
}

@test "video without a frame: exit 4, the wallpaper stays" {
    bad="$HOME/.local/wallpapers/broken.mkv"
    printf 'x' >"$bad"
    run "$SCRIPT" "$bad" none
    assert_failure 4
    assert_equal "$(cat "$STUB_LOG")" ""
    assert_equal "$(players | wc -l)" 0
}

@test "boot: a saved video plays again" {
    echo "$VID" >"$HOME/.local/wallpapers/.current"
    echo '{"wallpaper": {"transition": "none"}}' >"$STATE"
    run "$BOOT"
    assert_success
    wait_player
    assert_equal "$(players | wc -l)" 1
}

@test "poster of an image: the image itself, nothing made" {
    run poster_of "$WALL"
    assert_success
    assert_output "$WALL"
    assert_equal "$(cat "$STUB_LOG")" ""
}

# Frames of the video by second, with their brightness ("0:0 1:5 2:40"):
# ffmpeg writes the second it was asked for, ffprobe reads it back
frames_brightness() {
    export FRAMES="$1"
    cat >"$BATS_TEST_TMPDIR/bin/ffmpeg" <<'EOF2'
#!/bin/bash
for a; do :; done
at=0
while (($#)); do
    [[ "$1" == -ss ]] && at="$2"
    shift
done
[[ " $FRAMES " == *" $at:"* ]] || exit 0
echo "ffmpeg -ss $at" >>"$STUB_LOG"
printf '%s' "$at" >"$a"
EOF2
    cat >"$BATS_TEST_TMPDIR/bin/ffprobe" <<'EOF2'
#!/bin/bash
file="$(sed -n 's/.*movie=\([^,]*\),signalstats.*/\1/p' <<<"$*")"
at="$(cat "$file")"
for f in $FRAMES; do
    [[ "${f%%:*}" == "$at" ]] && echo "${f#*:}.5"
done
EOF2
    chmod +x "$BATS_TEST_TMPDIR/bin/ffmpeg" "$BATS_TEST_TMPDIR/bin/ffprobe"
}

@test "poster: a bright first frame, nothing else looked at" {
    frames_brightness "0:120 1:130"
    assert_equal "$(cat "$(poster_of "$VID")")" 0
    assert_equal "$(cat "$STUB_LOG")" "ffmpeg -ss 0"
}

@test "poster: a black first frame (a fade-in) gives way to the first bright one" {
    frames_brightness "0:0 1:5 2:40 3:90"
    assert_equal "$(cat "$(poster_of "$VID")")" 2
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 3
    run ls -A "$HOME/.cache/lyne/wallpaper-posters"
    assert_equal "$(grep -c . <<<"$output")" 1
}

@test "poster: a dark video gets its brightest frame, a short one what it has" {
    frames_brightness "0:0 1:9 2:4"
    assert_equal "$(cat "$(poster_of "$VID")")" 1
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 3
}

@test "video: paused and resumed through its socket" {
    "$SCRIPT" "$VID" none
    : >"$STUB_LOG"
    # Right after the start: it waits for the socket
    run "$VIDEO" pause yes
    assert_success
    run "$VIDEO" pause no
    assert_success
    assert_equal "$(grep '^ipc' "$STUB_LOG")" "ipc set_property pause true
ipc set_property pause false"
}

@test "video: frame rate capped only when the video is faster" {
    "$SCRIPT" "$VID" none
    : >"$STUB_LOG"
    # 30 fps under a cap of 15: frames dropped
    run "$VIDEO" fps 15
    assert_success
    # Under or at the cap (29.97 against 30): its own rate
    VIDEO_FPS=29.97 run "$VIDEO" fps 30
    assert_success
    # 0: no cap
    run "$VIDEO" fps 0
    assert_success
    assert_equal "$(grep '^ipc set_property vf' "$STUB_LOG")" "ipc set_property vf fps=15
ipc set_property vf 
ipc set_property vf "
    # Asked for the rate only when there is a cap
    assert_equal "$(grep -c '^ipc get_property container-fps' "$STUB_LOG")" 2
}

@test "video: no player, nothing to pause; bad commands" {
    run "$VIDEO" pause yes
    assert_failure 1
    run "$VIDEO" pause maybe
    assert_failure 2
    run "$VIDEO" rewind
    assert_failure 2
    run "$VIDEO" fps fast
    assert_failure 2
    assert_equal "$(cat "$STUB_LOG")" ""
}

@test "video without mpvpaper installed: its poster stays, no error" {
    # A PATH with the stand-ins and the tools the scripts use, mpvpaper left out
    nompv="$BATS_TEST_TMPDIR/nompv"
    mkdir -p "$nompv"
    for t in bash dirname realpath jq flock pgrep pkill head tail tr sed rm sleep sha1sum cut stat mkdir mv python3 setsid; do
        ln -s "$(PATH=/usr/bin:/bin command -v "$t")" "$nompv/$t"
    done
    ln -s "$BATS_TEST_TMPDIR/bin/awww" "$BATS_TEST_TMPDIR/bin/ffmpeg" "$nompv/"
    PATH="$nompv" run "$SCRIPT" "$VID" none
    assert_success
    assert_output --partial "mpvpaper not installed"
    assert_equal "$(grep '^awww' "$STUB_LOG")" "awww img $(poster_of "$VID") --transition-type none"
    assert_equal "$(players | wc -l)" 0
}
