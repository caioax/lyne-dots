#!/usr/bin/env bats
# scripts/wallpaper-set.sh (the transition of every wallpaper change) and
# the boot script that calls it, with a stand-in awww

load helpers

setup() {
    lyne_setup
    SCRIPT="$REPO/quickshell/.config/quickshell/scripts/wallpaper-set.sh"
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
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
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
