#!/usr/bin/env bats
# scripts/wallpapers-add.sh: Add and Add folder of Settings › Wallpaper,
# into a fake library

load helpers

setup() {
    lyne_setup
    SCRIPT="$REPO/quickshell/.config/quickshell/scripts/wallpapers-add.sh"
    LIBRARY="$HOME/.local/wallpapers"
    SRC="$BATS_TEST_TMPDIR/src"
    mkdir -p "$SRC"
}

# img PATH [CONTENT]: a fake image
img() {
    mkdir -p "$(dirname "$1")"
    printf '%s' "${2:-${1##*/}}" >"$1"
}

@test "files: copied, other types left out" {
    img "$SRC/a.jpg"
    img "$SRC/B.PNG"
    img "$SRC/notes.txt"
    run "$SCRIPT" "$LIBRARY" "$SRC/a.jpg" "$SRC/B.PNG" "$SRC/notes.txt" "$SRC/missing.jpg"
    assert_success
    assert_output "added:$LIBRARY/a.jpg
added:$LIBRARY/B.PNG"
    [[ -f "$LIBRARY/a.jpg" && ! -e "$LIBRARY/notes.txt" ]]
}

@test "folder: subfolders too, hidden ones left out" {
    img "$SRC/one.webp"
    img "$SRC/deep/er/two.gif"
    img "$SRC/deep/three.jpeg"
    img "$SRC/.cache/hidden.png"
    img "$SRC/deep/.hidden.png"
    img "$SRC/deep/readme.md"
    run "$SCRIPT" "$LIBRARY" "$SRC"
    assert_success
    assert_equal "$(grep -c '^added:' <<<"$output")" 3
    [[ -f "$LIBRARY/one.webp" && -f "$LIBRARY/two.gif" && -f "$LIBRARY/three.jpeg" ]]
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
