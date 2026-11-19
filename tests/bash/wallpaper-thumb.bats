#!/usr/bin/env bats
# scripts/wallpaper-thumb.sh: the small cached thumbnails the wallpaper tiles
# load instead of the full images, with a stand-in for ffmpeg

load helpers
bats_require_minimum_version 1.5.0

setup() {
    lyne_setup
    # LYNE_TEST_SHELL: a copy of the shell (to sabotage the script)
    SCRIPT="${LYNE_TEST_SHELL:-$REPO/quickshell/.config/quickshell}/scripts/wallpaper-thumb.sh"
    DIR="$HOME/.local/wallpapers"
    CACHE="$HOME/.cache/lyne/wallpaper-thumbs"
    mkdir -p "$DIR" "$BATS_TEST_TMPDIR/bin"
    IMG="$DIR/a.jpg"
    VID="$DIR/clip.mp4"
    printf 'img' >"$IMG"
    printf 'video' >"$VID"
    # ffmpeg: logs its input and filter, writes its last argument, fails
    # on a "broken" file
    cat >"$BATS_TEST_TMPDIR/bin/ffmpeg" <<'EOF'
#!/bin/bash
for a; do :; done
[[ "$*" == *broken* ]] && exit 1
input="" vf=""
while (($#)); do
    case "$1" in
        -i) input="$2" ;;
        -vf) vf="$2" ;;
    esac
    shift
done
echo "ffmpeg $input ${vf:-poster}" >>"$STUB_LOG"
printf 'out' >"$a"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/ffmpeg"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# The thumbnail printed for $2 by a run at size $1
thumb_of() {
    "$SCRIPT" "$1" "$2" | cut -f2
}

@test "image: a thumbnail covering the size, printed after its path" {
    run "$SCRIPT" 640x360 "$IMG"
    assert_success
    thumb="${output#*$'\t'}"
    assert_equal "$output" "$IMG"$'\t'"$thumb"
    [[ "$thumb" == "$CACHE"/*.jpg && -s "$thumb" ]]
    assert_equal "$(cat "$STUB_LOG")" "ffmpeg $IMG scale=640:360:force_original_aspect_ratio=increase:flags=lanczos"
}

@test "made once, made again when the file or the size changes" {
    first="$(thumb_of 640x360 "$IMG")"
    assert_equal "$(thumb_of 640x360 "$IMG")" "$first"
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 1
    printf 'another image' >"$IMG"
    touch -d '1 hour ago' "$IMG"
    second="$(thumb_of 640x360 "$IMG")"
    [[ "$second" != "$first" && -s "$second" ]]
    bigger="$(thumb_of 1280x720 "$IMG")"
    [[ "$bigger" != "$second" ]]
    assert_equal "$(grep -c '^ffmpeg' "$STUB_LOG")" 3
}

@test "video: the thumbnail comes from its poster" {
    run "$SCRIPT" 640x360 "$VID"
    assert_success
    poster="$(sed -n 's/^ffmpeg \(.*\) scale=.*/\1/p' "$STUB_LOG")"
    [[ "$poster" == "$HOME/.cache/lyne/wallpaper-posters/"*.jpg ]]
    assert_equal "$(head -1 "$STUB_LOG")" "ffmpeg $VID poster"
    assert_equal "$(wc -l <"$STUB_LOG")" 2
}

@test "a missing or broken file is left out, the others still come" {
    bad="$DIR/broken.png"
    printf 'x' >"$bad"
    run --separate-stderr "$SCRIPT" 640x360 "$bad" "$DIR/gone.jpg" "$IMG"
    assert_success
    assert_equal "$(grep -c . <<<"$output")" 1
    assert_equal "$(grep -c . <<<"$stderr")" 2
    assert_equal "${output%%$'\t'*}" "$IMG"
    run ls -A "$CACHE"
    assert_equal "$(grep -c . <<<"$output")" 1
}

@test "every path of a batch gets its line" {
    for n in 1 2 3 4 5 6; do printf 'img%s' "$n" >"$DIR/w$n.png"; done
    # Read as soon as the script exits, like the shell's Process does: no
    # line may come after that
    "$SCRIPT" 640x360 "$DIR"/w*.png >"$BATS_TEST_TMPDIR/out"
    out="$(cat "$BATS_TEST_TMPDIR/out")"
    assert_equal "$(cut -f1 <<<"$out" | sort | tr '\n' ' ')" "$(printf '%s ' "$DIR"/w*.png)"
}

@test "a bad size: usage, exit 2" {
    run "$SCRIPT" big "$IMG"
    assert_failure 2
    assert_equal "$(cat "$STUB_LOG")" ""
}

@test "cache: files unused for a month go, the ones in use stay" {
    POSTERS="$HOME/.cache/lyne/wallpaper-posters"
    keep="$(thumb_of 320x180 "$IMG")"
    keep_poster="$("${SCRIPT%/*}/wallpaper-poster.sh" "$VID")"
    mkdir -p "$CACHE" "$POSTERS"
    printf 'old' >"$CACHE/gone.jpg"
    printf 'old' >"$POSTERS/gone.jpg"
    printf 'old' >"$CACHE/.half.123.jpg"
    printf 'new' >"$CACHE/recent.jpg"
    touch -d '40 days ago' "$keep" "$keep_poster" "$CACHE/gone.jpg" "$POSTERS/gone.jpg" "$CACHE/.half.123.jpg"
    touch -d '10 days ago' "$CACHE/recent.jpg"
    rm -f "$HOME/.cache/lyne/.wallpaper-cache-pruned"
    run "$SCRIPT" 320x180 "$IMG" "$VID"
    assert_success
    # Asked for again: touched before the next prune
    assert [ -f "$keep" ]
    assert [ -f "$keep_poster" ]
    refute [ -e "$CACHE/gone.jpg" ]
    refute [ -e "$POSTERS/gone.jpg" ]
    refute [ -e "$CACHE/.half.123.jpg" ]
    assert [ -f "$CACHE/recent.jpg" ]
    find "$keep" -mmin -5 | grep -q .
}

@test "cache: pruned once a day" {
    mkdir -p "$CACHE"
    touch "$HOME/.cache/lyne/.wallpaper-cache-pruned"
    printf 'old' >"$CACHE/gone.jpg"
    touch -d '40 days ago' "$CACHE/gone.jpg"
    run "$SCRIPT" 320x180 "$IMG"
    assert_success
    assert [ -f "$CACHE/gone.jpg" ]
}
