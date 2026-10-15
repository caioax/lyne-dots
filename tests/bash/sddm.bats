#!/usr/bin/env bats
# lib/sddm.sh: the login screen files in a fake /var/lib/lyne-sddm

load helpers

setup() {
    lyne_setup
    fake_dots
    export LYNE_SDDM_DIR="$BATS_TEST_TMPDIR/lyne-sddm" LYNE_SDDM_PALETTE="$HOME/.cache/lyne/nvim.json"
    mkdir -p "$LYNE_SDDM_DIR/avatars" "$HOME/.cache/lyne" "$HOME/Pictures"
    jq '{palette}' "$REPO/.data/themes/tokyonight.json" >"$LYNE_SDDM_PALETTE"
    printf 'jpg' >"$HOME/Pictures/wall.JPG"
    printf 'png' >"$HOME/Pictures/me.png"
    STATE="$HOME/.config/quickshell/state.json"
    set_state '.sddm.sync = true | .wallpaper.current = $w | .profile.avatar = $a | .opacity.background = 0.85' \
        --arg w "$HOME/Pictures/wall.JPG" --arg a "$HOME/Pictures/me.png"
}

teardown() {
    chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null
    repo_unchanged
}

set_state() { jq "$@" "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
sddm() { in_lyne sddm -- "$1"; }
conf() { cat "$LYNE_SDDM_DIR/theme.conf.user"; }

@test "state: ok, missing, not writable" {
    run sddm sddm_state
    assert_output ok
    chmod a-w "$LYNE_SDDM_DIR"
    run sddm 'sddm_state; sddm_problem'
    assert_line "foreign $(id -un)"
    assert_line "$LYNE_SDDM_DIR isn't writable: run lyne-sddm"
    chmod u+w "$LYNE_SDDM_DIR"
    rm -rf "$LYNE_SDDM_DIR"
    run sddm 'sddm_state; sddm_problem'
    assert_line missing
    assert_line "$LYNE_SDDM_DIR doesn't exist: run lyne-sddm"
}

@test "apply: palette, opacity, wallpaper and avatar copied, world-readable" {
    run sddm sddm_apply
    assert_success
    run conf
    assert_line "[General]"
    assert_line "background=#1a1b26"
    assert_line "accent=#7aa2f7"
    assert_line "backgroundOpacity=0.85"
    assert_line "wallpaper=$LYNE_SDDM_DIR/wallpaper.jpg"
    assert_equal "$(cat "$LYNE_SDDM_DIR/wallpaper.jpg")" jpg
    assert_equal "$(cat "$LYNE_SDDM_DIR/avatars/$(id -un).png")" png
    assert_equal "$(stat -c %a "$LYNE_SDDM_DIR/theme.conf.user" "$LYNE_SDDM_DIR/wallpaper.jpg" | sort -u)" 644
    run ls -A "$LYNE_SDDM_DIR"
    refute_output --partial ".lyne."
}

@test "apply again writes nothing; a new wallpaper replaces the old copy" {
    run sddm sddm_apply
    local before
    before="$(stat -c '%i %n' "$LYNE_SDDM_DIR"/* | sort)"
    run sddm sddm_apply
    assert_equal "$(stat -c '%i %n' "$LYNE_SDDM_DIR"/* | sort)" "$before"
    printf 'png wall' >"$HOME/Pictures/new.png"
    set_state '.wallpaper.current = $w' --arg w "$HOME/Pictures/new.png"
    run sddm sddm_apply
    assert [ -f "$LYNE_SDDM_DIR/wallpaper.png" ]
    refute [ -e "$LYNE_SDDM_DIR/wallpaper.jpg" ]
}

@test "options: LYNE_SDDM_OPTIONS over state.json, even empty; no avatar removes the copy" {
    run sddm sddm_apply
    run sddm 'LYNE_SDDM_OPTIONS='"'"'{"opacity": 1}'"'"' sddm_apply'
    assert_success
    run conf
    assert_line "backgroundOpacity=1"
    assert [ -e "$LYNE_SDDM_DIR/avatars/$(id -un).png" ]
    # An empty value in the options wins over state.json (saved a moment later)
    run sddm 'LYNE_SDDM_OPTIONS='"'"'{"avatar": ""}'"'"' sddm_apply'
    refute [ -e "$LYNE_SDDM_DIR/avatars/$(id -un).png" ]
    run sddm sddm_apply
    assert [ -e "$LYNE_SDDM_DIR/avatars/$(id -un).png" ]
    set_state '.profile.avatar = ""'
    run sddm sddm_apply
    refute [ -e "$LYNE_SDDM_DIR/avatars/$(id -un).png" ]
}

@test "sync off: back to the theme's defaults" {
    run sddm sddm_apply
    set_state '.sddm.sync = false'
    run sddm sddm_apply
    assert_success
    run conf
    assert_line --index 0 "[General]"
    refute_output --partial "accent="
    run ls "$LYNE_SDDM_DIR"
    refute_output --partial wallpaper
}

@test "values with a comma are quoted (SDDM would read a list)" {
    jq '.palette.font = "Inter, sans"' "$LYNE_SDDM_PALETTE" >"$BATS_TEST_TMPDIR/p" && mv "$BATS_TEST_TMPDIR/p" "$LYNE_SDDM_PALETTE"
    run sddm sddm_apply
    run conf
    assert_line 'font="Inter, sans"'
}

@test "can't apply: nothing written, the reason on stderr" {
    rm -rf "$LYNE_SDDM_DIR"
    run sddm 'sddm_apply 2>&1'
    assert_failure
    assert_output --partial "doesn't exist: run lyne-sddm"
    refute [ -e "$LYNE_SDDM_DIR" ]
}
