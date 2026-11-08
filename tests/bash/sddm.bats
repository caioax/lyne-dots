#!/usr/bin/env bats
# lib/sddm.sh: the login screen files in a fake /var/lib/lyne-sddm

load helpers

setup() {
    lyne_setup
    fake_dots
    export LYNE_SDDM_DIR="$BATS_TEST_TMPDIR/lyne-sddm" LYNE_SDDM_PALETTE="$HOME/.cache/lyne/nvim.json"
    export LYNE_SDDM_THEME="$BATS_TEST_TMPDIR/theme"
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

@test "layout: from sddm.layout, center when unset, unknown or path-like" {
    run sddm sddm_apply
    run conf
    assert_line "layout=center"
    set_state '.sddm.layout = "Cards"'
    run sddm sddm_apply
    run conf
    assert_line "layout=cards"
    refute_line "layout=center"
    set_state '.sddm.layout = "../x"'
    run sddm sddm_apply
    run conf
    assert_line "layout=center"
    run sddm 'LYNE_SDDM_OPTIONS='"'"'{"layout": "wallpaper"}'"'"' sddm_apply'
    run conf
    assert_line "layout=wallpaper"
}

@test "layouts: the theme's layouts/*.qml, lowercase ids, thumbnails when shipped" {
    mkdir -p "$LYNE_SDDM_THEME/layouts"
    touch "$LYNE_SDDM_THEME/layouts/"{Center.qml,Center.png,Cards.qml,Split-View.qml,notes.txt}
    run sddm sddm_layouts
    assert_success
    assert_line "center $LYNE_SDDM_THEME/layouts/Center.png"
    assert_line "cards "
    refute_output --partial split
    refute_output --partial notes
    rm -rf "$LYNE_SDDM_THEME/layouts"
    run sddm sddm_layouts
    assert_output ""
}

@test "mode: synced, manual or default, by the header on any line" {
    run sddm sddm_mode
    assert_output default
    run sddm sddm_apply
    run sddm sddm_mode
    assert_output synced
    printf '[General]\n# Written by lyne-sddm (manual)\naccent=#ff0000\n' >"$LYNE_SDDM_DIR/theme.conf.user"
    run sddm sddm_mode
    assert_output manual
    printf '[General]\n# Overrides of theme.conf, written by lyne-dots (see docs/sync.md).\n' >"$LYNE_SDDM_DIR/theme.conf.user"
    run sddm sddm_mode
    assert_output default
}

@test "sync off: manual choices and the template are left alone" {
    set_state '.sddm.sync = false'
    local manual='[General]
# Written by lyne-sddm (manual)
accent=#ff0000
layout=cards
wallpaper='"$LYNE_SDDM_DIR"'/wallpaper.png'
    printf '%s\n' "$manual" >"$LYNE_SDDM_DIR/theme.conf.user"
    printf 'mine' >"$LYNE_SDDM_DIR/wallpaper.png"
    run sddm sddm_apply
    assert_success
    assert_equal "$(conf)" "$manual"
    assert_equal "$(cat "$LYNE_SDDM_DIR/wallpaper.png")" mine
    # Sync on: lyne-dots wins and replaces it all
    set_state '.sddm.sync = true'
    run sddm sddm_apply
    run sddm sddm_mode
    assert_output synced
    refute [ -e "$LYNE_SDDM_DIR/wallpaper.png" ]
}

@test "lyne sddm status: mode and layout" {
    set_state '.sddm.layout = "cards"'
    run lyne sddm status
    assert_line --partial "theme defaults"
    refute_line --partial "Layout"
    run lyne sddm apply
    run lyne sddm status
    assert_line --regexp "Mode +synced by lyne-dots"
    assert_line --regexp "Layout +cards"
    printf '[General]\n# Written by lyne-sddm (manual)\n' >"$LYNE_SDDM_DIR/theme.conf.user"
    set_state '.sddm.sync = false'
    run lyne sddm status
    assert_line --regexp "Sync +off"
    assert_line --regexp "Mode +manual"
    assert_line --regexp "Layout +center"
}

# lyne sddm install against a local repo, with makepkg and lyne-sddm logged
install_stubs() {
    local bin="$BATS_TEST_TMPDIR/bin" cmd
    mkdir -p "$bin"
    for cmd in makepkg lyne-sddm; do
        printf '#!/bin/bash\necho "%s $* (in $PWD)" >>"$STUB_LOG"\n' "$cmd" >"$bin/$cmd"
        chmod +x "$bin/$cmd"
    done
    export PATH="$bin:$PATH"
    local src="$BATS_TEST_TMPDIR/lyne-sddm-src"
    git init -q -b main "$src" && touch "$src/PKGBUILD" && git -C "$src" add PKGBUILD && git -C "$src" commit -qm init
    export LYNE_SDDM_REPO="file://$src"
}

@test "install: clone, makepkg, lyne-sddm, then sync; again pulls the clone" {
    install_stubs
    run lyne sddm install
    assert_success
    assert_output --partial "Login screen installed and synced"
    local build="$HOME/.cache/lyne/lyne-sddm"
    assert [ -f "$build/PKGBUILD" ]
    run cat "$STUB_LOG"
    assert_line --partial "pacman -S --needed --noconfirm git base-devel"
    assert_line "makepkg -sicf --noconfirm --needed (in $build)"
    assert_line --regexp "^lyne-sddm  ?\(in "
    run sddm sddm_mode
    assert_output synced
    touch "$BATS_TEST_TMPDIR/lyne-sddm-src/new" && git -C "$BATS_TEST_TMPDIR/lyne-sddm-src" add new && git -C "$BATS_TEST_TMPDIR/lyne-sddm-src" commit -qm new
    run lyne sddm install
    assert_success
    assert_output --partial "Updating $build"
    assert [ -f "$build/new" ]
}

@test "install: a script install is refused, a failed build stops before lyne-sddm" {
    install_stubs
    mkdir -p "$LYNE_SDDM_THEME" && touch "$LYNE_SDDM_THEME/metadata.desktop"
    run lyne sddm install
    assert_failure
    assert_output --partial "./install.sh --uninstall"
    # The package's own files are no script install
    export FAKE_OWNED="$BATS_TEST_TMPDIR/owned"
    echo "$LYNE_SDDM_THEME/metadata.desktop lyne-sddm-git" >"$FAKE_OWNED"
    run lyne sddm install
    assert_success
    rm "$LYNE_SDDM_THEME/metadata.desktop"
    printf '#!/bin/bash\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/makepkg"
    : >"$STUB_LOG"
    run lyne sddm install
    assert_failure
    assert_output --partial "the install stopped"
    run cat "$STUB_LOG"
    refute_line --partial "lyne-sddm"
}

@test "dm: the display manager systemd starts, empty without one" {
    export LYNE_DM_LINK="$BATS_TEST_TMPDIR/display-manager.service"
    run sddm sddm_dm
    assert_output ""
    ln -s /usr/lib/systemd/system/sddm.service "$LYNE_DM_LINK"
    run sddm sddm_dm
    assert_output sddm
}
