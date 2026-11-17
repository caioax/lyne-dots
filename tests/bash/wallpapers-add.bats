#!/usr/bin/env bats
# scripts/wallpapers-add.sh: Add and Add folder of Settings › Wallpaper,
# into a fake library

load helpers

setup() {
    lyne_setup
    SCRIPT="$REPO/quickshell/.config/quickshell/scripts/wallpapers-add.sh"
    LIBRARY="$HOME/.local/wallpapers"
    SRC="$BATS_TEST_TMPDIR/src"
    mkdir -p "$SRC" "$BATS_TEST_TMPDIR/bin"
    # A fake video holds its size ("3840x2160"); a scaled copy holds
    # "scaled WxH TAG". ffprobe reads those back, ffmpeg writes the copy and
    # reports progress; ffmpeg fails on a "broken" source
    cat >"$BATS_TEST_TMPDIR/bin/ffprobe" <<'EOF'
#!/bin/bash
for f; do :; done
read -r first size tag <"$f"
case "$*" in
    *stream=width,height*) [[ "$first" == scaled ]] && echo "$size" || echo "$first" ;;
    *format=duration*) echo 10.000000 ;;
    *format_tags=comment*) [[ "$first" == scaled ]] && echo "$tag" ;;
esac
exit 0
EOF
    cat >"$BATS_TEST_TMPDIR/bin/ffmpeg" <<'EOF'
#!/bin/bash
echo "ffmpeg $*" >>"$STUB_LOG"
[[ "$*" == *broken* ]] && exit 1
for f; do :; done
args=("$@")
for i in "${!args[@]}"; do
    [[ "${args[i]}" == -vf ]] && size="${args[i + 1]#scale=}" && size="${size%%:flags*}" && size="${size/:/x}"
    [[ "${args[i]}" == -metadata ]] && tag="${args[i + 1]#comment=}"
done
echo "scaled $size $tag" >"$f"
printf 'out_time_us=2500000\nprogress=continue\nout_time_us=10000000\nprogress=end\n'
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# img PATH [CONTENT]: a fake image
img() {
    mkdir -p "$(dirname "$1")"
    printf '%s' "${2:-${1##*/}}" >"$1"
}

@test "files: images and videos copied, other types (gif too) left out" {
    img "$SRC/a.jpg"
    img "$SRC/B.PNG"
    img "$SRC/clip.MP4" 1280x720
    img "$SRC/loop.gif"
    img "$SRC/notes.txt"
    run "$SCRIPT" "$LIBRARY" "$SRC/a.jpg" "$SRC/B.PNG" "$SRC/clip.MP4" "$SRC/loop.gif" "$SRC/notes.txt" "$SRC/missing.jpg"
    assert_success
    assert_output "added:$LIBRARY/a.jpg
added:$LIBRARY/B.PNG
added:$LIBRARY/clip.MP4"
    [[ -f "$LIBRARY/a.jpg" && ! -e "$LIBRARY/notes.txt" && ! -e "$LIBRARY/loop.gif" ]]
}

@test "folder: subfolders too, hidden ones left out" {
    img "$SRC/one.webp"
    img "$SRC/deep/er/two.webm" 1920x1080
    img "$SRC/deep/three.jpeg"
    img "$SRC/.cache/hidden.png"
    img "$SRC/deep/.hidden.png"
    img "$SRC/deep/readme.md"
    run "$SCRIPT" "$LIBRARY" "$SRC"
    assert_success
    assert_equal "$(grep -c '^added:' <<<"$output")" 3
    [[ -f "$LIBRARY/one.webp" && -f "$LIBRARY/two.webm" && -f "$LIBRARY/three.jpeg" ]]
    [[ ! -e "$LIBRARY/hidden.png" && ! -e "$LIBRARY/.hidden.png" ]]
}

@test "the same image again is skipped" {
    img "$SRC/a.jpg" same
    run "$SCRIPT" "$LIBRARY" "$SRC"
    run "$SCRIPT" "$LIBRARY" "$SRC"
    assert_success
    assert_output "skipped:$SRC/a.jpg"
    [[ ! -e "$LIBRARY/a-1.jpg" ]]
}

@test "another image with a taken name gets a number" {
    img "$LIBRARY/a.jpg" mine
    img "$LIBRARY/a-1.jpg" also-mine
    img "$SRC/x/a.jpg" first
    img "$SRC/y/a.jpg" second
    run "$SCRIPT" "$LIBRARY" "$SRC"
    assert_success
    assert_output "added:$LIBRARY/a-2.jpg
added:$LIBRARY/a-3.jpg"
    assert_equal "$(cat "$LIBRARY/a.jpg")" mine
    assert_equal "$(cat "$LIBRARY/a-2.jpg")" first
    assert_equal "$(cat "$LIBRARY/a-3.jpg")" second
}

@test "the library itself and its themes folder: nothing copied" {
    img "$LIBRARY/a.jpg"
    img "$LIBRARY/themes/nord/b.jpg"
    run "$SCRIPT" "$LIBRARY" "$LIBRARY"
    assert_success
    refute_output --partial "added:"
    run "$SCRIPT" "$LIBRARY" "$LIBRARY/themes"
    refute_output --partial "added:"
    [[ ! -e "$LIBRARY/b.jpg" ]]
}

@test "a library reached through a link counts as the library" {
    img "$BATS_TEST_TMPDIR/real/a.jpg"
    mkdir -p "$HOME/.local"
    ln -s "$BATS_TEST_TMPDIR/real" "$LIBRARY"
    run "$SCRIPT" "$LIBRARY" "$BATS_TEST_TMPDIR/real"
    assert_success
    assert_output "skipped:$BATS_TEST_TMPDIR/real/a.jpg"
}

@test "names with spaces and quotes" {
    img "$SRC/it's a \"cat\".png"
    run "$SCRIPT" "$LIBRARY" "$SRC"
    assert_success
    assert_output "added:$LIBRARY/it's a \"cat\".png"
}

@test "an empty folder: no output" {
    run "$SCRIPT" "$LIBRARY" "$SRC"
    assert_success
    assert_output ""
}

@test "fit: a larger video is stored scaled to cover the screen, as mp4, with progress" {
    img "$SRC/big.mkv" 3840x2160
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC/big.mkv"
    assert_success
    poster="$(ls "$HOME/.cache/lyne/wallpaper-posters/"*.jpg)"
    assert_output "$(printf 'fitting:%s\t%s\nprogress:%s\t25\nprogress:%s\t99\nadded:%s' \
        "$LIBRARY/big.mp4" "$poster" "$LIBRARY/big.mp4" "$LIBRARY/big.mp4" "$LIBRARY/big.mp4")"
    read -r _ size tag <"$LIBRARY/big.mp4"
    assert_equal "$size" 1920x1080
    assert_equal "$tag" "lyne-source:$(sha1sum "$SRC/big.mkv" | cut -d' ' -f1)"
    # The source as it was, no temporary file left
    assert_equal "$(cat "$SRC/big.mkv")" 3840x2160
    assert_equal "$(ls -A "$LIBRARY")" big.mp4
    # No notification: Settings shows the progress
    run grep -c '^notify-send' "$STUB_LOG"
    assert_output 0
}

@test "fit: a cancelled video is not added, the next one is" {
    img "$SRC/a.mp4" 3840x2160
    img "$SRC/b.mp4" "3840x2160 b"
    echo "$LIBRARY/a.mp4" >"$BATS_TEST_TMPDIR/cancel"
    LYNE_ADD_CANCEL="$BATS_TEST_TMPDIR/cancel" run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC"
    assert_success
    assert_line "cancelled:$LIBRARY/a.mp4"
    assert_line "added:$LIBRARY/b.mp4"
    assert_equal "$(ls -A "$LIBRARY")" b.mp4
}

@test "fit: another shape keeps it, covering the screen" {
    img "$SRC/tall.mp4" 2160x3840
    img "$SRC/wide.mp4" 5120x1440
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC"
    assert_success
    read -r _ size _ <"$LIBRARY/tall.mp4"
    assert_equal "$size" 1920x3414
    read -r _ size _ <"$LIBRARY/wide.mp4"
    assert_equal "$size" 3840x1080
}

@test "fit: a video that already fits is copied as it is" {
    img "$SRC/small.webm" 1920x1080
    img "$SRC/narrow.mp4" 1280x2000
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC"
    assert_success
    assert_equal "$(cat "$LIBRARY/small.webm")" 1920x1080
    assert_equal "$(cat "$LIBRARY/narrow.mp4")" 1280x2000
    run grep -c '^ffmpeg' "$STUB_LOG"
    assert_output 0
}

@test "fit: the same large video again is skipped, another one gets a number" {
    img "$SRC/big.mp4" 3840x2160
    "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC/big.mp4"
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC/big.mp4"
    assert_output "skipped:$SRC/big.mp4"
    img "$SRC/other/big.mp4" "3840x2160 other"
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC/other/big.mp4"
    assert_line "added:$LIBRARY/big-1.mp4"
}

@test "fit: a video ffmpeg can't read is not added" {
    img "$SRC/broken.mp4" 3840x2160
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC/broken.mp4"
    assert_success
    assert_line "failed:$LIBRARY/broken.mp4"
    refute_output --partial "added:"""
    assert_equal "$(ls -A "$LIBRARY")" ""
}

@test "a video ffprobe can't read is left out, reported as failed" {
    img "$SRC/notavideo.mp4" "just text"
    img "$SRC/ok.jpg"
    run "$SCRIPT" --fit 1920x1080 "$LIBRARY" "$SRC"
    assert_success
    assert_output "failed:$SRC/notavideo.mp4
added:$LIBRARY/ok.jpg"
    [[ ! -e "$LIBRARY/notavideo.mp4" ]]
}
