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
        printf '#!/bin/bash\necho "%s $* (in $PWD${LYNE_SDDM_REF:+, ref $LYNE_SDDM_REF})" >>"$STUB_LOG"\n[[ $0 == *makepkg ]] && touch lyne-sddm-git-1-any.pkg.tar.zst\nexit 0\n' "$cmd" >"$bin/$cmd"
        chmod +x "$bin/$cmd"
    done
    export PATH="$bin:$PATH"
    SRC="$BATS_TEST_TMPDIR/lyne-sddm-src"
    git init -q -b main "$SRC" && touch "$SRC/PKGBUILD" && git -C "$SRC" add PKGBUILD && git -C "$SRC" commit -qm init
    export LYNE_SDDM_REPO="file://$SRC"
}

# src_commit NAME [TAG]: a commit in the fake lyne-sddm repo, annotated tag
src_commit() {
    touch "$SRC/$1" && git -C "$SRC" add "$1" && git -C "$SRC" commit -qm "$1"
    if [[ -n "${2:-}" ]]; then git -C "$SRC" tag -a "$2" -m "$2"; fi
}
sha() { git -C "$SRC" rev-parse "$1"; }
# installed NAME: lyne-sddm-git built from that commit of the fake repo
installed() { echo "lyne-sddm-git ${2:-0.2.0.r0}.g$(git -C "$SRC" rev-parse --short=7 "$1^{commit}")-1" >"$FAKE_PKGS"; }

@test "install: clone, makepkg, lyne-sddm, then sync; again pulls the clone" {
    install_stubs
    run lyne sddm install
    assert_success
    assert_output --partial "Login screen installed and synced"
    local build="$HOME/.cache/lyne/lyne-sddm"
    assert [ -f "$build/PKGBUILD" ]
    # The package file goes once installed
    refute compgen -G "$build/*.pkg.tar.*"
    run cat "$STUB_LOG"
    assert_line --partial "pacman -S --needed --noconfirm git base-devel"
    # No release yet: stable builds main
    assert_line "makepkg -sicf --noconfirm --needed (in $build)"
    assert_line --regexp "^lyne-sddm  ?\(in "
    run sddm sddm_mode
    assert_output synced
    src_commit new
    run lyne sddm install
    assert_success
    assert_output --partial "Updating $build"
    assert [ -f "$build/new" ]
}

@test "install: a script install is kept without a terminal or on no; a failed build stops before lyne-sddm" {
    install_stubs
    mkdir -p "$LYNE_SDDM_THEME" && touch "$LYNE_SDDM_THEME/metadata.desktop"
    run lyne sddm install </dev/null
    assert_failure
    assert_output --partial "left as it is"
    run sddm 'echo n | sddm_install stable 1'
    assert_failure
    assert [ -f "$LYNE_SDDM_THEME/metadata.desktop" ]
    run cat "$STUB_LOG"
    refute_line --partial makepkg
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

@test "install: a script install is replaced once the package is built, settings kept" {
    install_stubs
    mkdir -p "$LYNE_SDDM_THEME" && touch "$LYNE_SDDM_THEME/metadata.desktop"
    run sddm sddm_apply
    local conf
    conf=$(conf)
    # A failed build leaves the script install as it was
    local bin="$BATS_TEST_TMPDIR/bin"
    mv "$bin/makepkg" "$bin/makepkg.ok" && printf '#!/bin/bash\nexit 1\n' >"$bin/makepkg" && chmod +x "$bin/makepkg"
    run sddm 'echo | sddm_install stable 1'
    assert_failure
    assert [ -f "$LYNE_SDDM_THEME/metadata.desktop" ]
    mv "$bin/makepkg.ok" "$bin/makepkg"
    : >"$STUB_LOG"
    run sddm 'echo | sddm_install stable 1'
    assert_success
    run cat "$STUB_LOG"
    assert_line "makepkg -scf --noconfirm (in $HOME/.cache/lyne/lyne-sddm)"
    assert_line "sudo rm -rf -- $LYNE_SDDM_THEME"
    assert_line "sudo pacman -U --noconfirm $HOME/.cache/lyne/lyne-sddm/lyne-sddm-git-1-any.pkg.tar.zst"
    assert_line --regexp "^lyne-sddm  ?\(in "
    refute [ -e "$LYNE_SDDM_THEME" ]
    # The sync dir and its files are the package's too
    assert_equal "$(conf)" "$conf"
    refute compgen -G "$HOME/.cache/lyne/lyne-sddm/*.pkg.tar.*"
}

@test "dm: the display manager systemd starts, empty without one" {
    export LYNE_DM_LINK="$BATS_TEST_TMPDIR/display-manager.service"
    run sddm sddm_dm
    assert_output ""
    ln -s /usr/lib/systemd/system/sddm.service "$LYNE_DM_LINK"
    run sddm sddm_dm
    assert_output sddm
}

@test "target: stable = newest annotated vX.Y.Z by version, else main; latest = main" {
    install_stubs
    run sddm 'sddm_target stable'
    assert_output "main $(sha main)"
    src_commit a v0.9.0
    src_commit b v0.10.0
    src_commit c
    git -C "$SRC" tag v0.11.0    # lightweight: git describe skips it
    git -C "$SRC" tag -a v1.0.0-rc -m rc
    run sddm 'sddm_target stable'
    assert_output "v0.10.0 $(sha "v0.10.0^{commit}")"
    run sddm 'sddm_target latest'
    assert_output "main $(sha main)"
    LYNE_SDDM_REPO="file://$BATS_TEST_TMPDIR/nowhere" run sddm 'sddm_target stable'
    assert_failure
}

@test "update check: none, current, available, unknown; by hash prefix" {
    install_stubs
    src_commit a v0.2.0
    run sddm 'sddm_update_check stable; echo $SDDM_UPD_STATE'
    assert_output none
    installed v0.2.0
    run sddm 'sddm_update_check stable; echo "$SDDM_UPD_STATE $SDDM_UPD_REF"'
    assert_output "current v0.2.0"
    src_commit b
    run sddm 'sddm_update_check stable; echo $SDDM_UPD_STATE'
    assert_output current
    run sddm 'sddm_update_check latest; echo "$SDDM_UPD_STATE $SDDM_UPD_REF $SDDM_UPD_SHA"'
    assert_output "available main $(sha main)"
    # A longer hash in the pkgver (git lengthens ambiguous ones)
    echo "lyne-sddm-git 0.2.0.r1.g$(git -C "$SRC" rev-parse --short=10 main)-1" >"$FAKE_PKGS"
    run sddm 'sddm_update_check latest; echo $SDDM_UPD_STATE'
    assert_output current
    LYNE_SDDM_REPO="file://$BATS_TEST_TMPDIR/nowhere" run sddm 'sddm_update_check latest; echo $SDDM_UPD_STATE'
    assert_output unknown
    # A script install isn't followed
    mkdir -p "$LYNE_SDDM_THEME" && touch "$LYNE_SDDM_THEME/metadata.desktop"
    run sddm 'sddm_update_check latest; echo $SDDM_UPD_STATE'
    assert_output none
}

@test "install follows the channel: stable builds the release through LYNE_SDDM_REF, the clone stays on main" {
    install_stubs
    src_commit a v0.2.0
    src_commit b
    run sddm 'sddm_install stable'
    assert_success
    run cat "$STUB_LOG"
    assert_line "makepkg -sicf --noconfirm --needed (in $HOME/.cache/lyne/lyne-sddm, ref v0.2.0)"
    assert_equal "$(git -C "$HOME/.cache/lyne/lyne-sddm" rev-parse HEAD)" "$(sha main)"
    : >"$STUB_LOG"
    run sddm 'sddm_install latest'
    run cat "$STUB_LOG"
    assert_line "makepkg -sicf --noconfirm --needed (in $HOME/.cache/lyne/lyne-sddm)"
    # makepkg rewrites pkgver= in the clone; a new PKGBUILD upstream still comes in
    echo "pkgver=0.2.0.r1.gabc1234" >"$HOME/.cache/lyne/lyne-sddm/PKGBUILD"
    echo "pkgver=0.2.0.r0.gdef5678" >"$SRC/PKGBUILD" && git -C "$SRC" commit -qam pkgbuild
    run sddm 'sddm_build ""'
    assert_success
    assert_equal "$(cat "$HOME/.cache/lyne/lyne-sddm/PKGBUILD")" "pkgver=0.2.0.r0.gdef5678"
}

@test "offer update: asks with a terminal, rebuilds on yes, not on no; only says how without one" {
    install_stubs
    src_commit a v0.2.0
    installed v0.2.0
    src_commit b v0.3.0
    run sddm 'echo n | sddm_offer_update stable 1'
    assert_success
    assert_output --partial "New version: $(git -C "$SRC" rev-parse --short=7 "v0.2.0^{commit}") -> $(git -C "$SRC" rev-parse --short=7 "v0.3.0^{commit}") (v0.3.0)"
    run cat "$STUB_LOG"
    refute_line --partial makepkg
    run sddm 'echo | sddm_offer_update stable 1'
    assert_output --partial "lyne-sddm updated"
    run cat "$STUB_LOG"
    assert_line --partial "ref v0.3.0)"
    refute_line --partial "lyne-sddm "
    : >"$STUB_LOG"
    run sddm 'sddm_offer_update stable 0 </dev/null'
    assert_output --partial "Run lyne update in a terminal"
    run cat "$STUB_LOG"
    refute_line --partial makepkg
    # Nothing new: silent
    installed v0.3.0 0.3.0.r0
    run sddm 'sddm_offer_update stable 1 </dev/null'
    assert_output ""
}

@test "stable never downgrades a build from latest; a newer release replaces it" {
    install_stubs
    src_commit a v0.2.0
    src_commit b
    installed main 0.2.0.r1
    run sddm 'sddm_update_check stable; echo $SDDM_UPD_STATE'
    assert_output ahead
    run sddm 'sddm_offer_update stable 1 </dev/null'
    assert_output ""
    src_commit c v0.2.1
    run sddm 'sddm_update_check stable; echo "$SDDM_UPD_STATE $SDDM_UPD_REF"'
    assert_output "available v0.2.1"
}
