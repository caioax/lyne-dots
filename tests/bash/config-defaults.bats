#!/usr/bin/env bats
# lib/config-defaults.sh: the config files each machine keeps for itself
# (out of git) and their defaults in .data/config-defaults

load helpers

setup() {
    lyne_setup
    mkdir -p "$DOTS_DIR/.data"
    cp -r "$REPO/.data/config-defaults" "$DOTS_DIR/.data/"
}

files() { in_lyne config-defaults -- 'printf "%s\n" "${CONFIG_DEFAULT_FILES[@]}"'; }

@test "each file is out of git, ignored, and has a default; no default without its file" {
    run files
    assert_success
    local path
    for path in "${lines[@]}"; do
        # A tracked one would show each choice in git status again
        run git -C "$REPO" ls-files --error-unmatch -- "$path"
        assert_failure
        git -C "$REPO" check-ignore -q --no-index -- "$path"
        assert [ -f "$REPO/.data/config-defaults/$path" ]
    done
    run bash -c "cd '$REPO/.data/config-defaults' && find . -type f | sed 's|^\./||' | sort"
    assert_equal "$output" "$(files | sort)"
}

@test "the defaults use lyne's default icon theme, in its dark variant" {
    run in_lyne icons -- 'echo "$ICONS_DEFAULT_THEME"'
    local dark="$output-dark" d="$REPO/.data/config-defaults"
    grep -qx "Theme=$dark" "$d/kde/.config/kdeglobals"
    grep -qx "icon_theme=$dark" "$d/theming/.config/qt6ct/qt6ct.conf"
    grep -qx "icon_theme=$dark" "$d/theming/.config/qt5ct/qt5ct.conf"
    grep -qx "gtk-icon-theme-name=$dark" "$d/theming/.config/gtk-3.0/settings.ini"
    grep -qx "gtk-icon-theme-name=$dark" "$d/theming/.config/gtk-4.0/settings.ini"
}

@test "seed: the missing ones from their defaults, folders made; files and links there stay" {
    mkdir -p "$DOTS_DIR/theming/.config/qt6ct"
    echo mine >"$DOTS_DIR/theming/.config/qt6ct/qt6ct.conf"
    mkdir -p "$DOTS_DIR/theming/.config/gtk-4.0"
    ln -s nowhere "$DOTS_DIR/theming/.config/gtk-4.0/settings.ini"
    run in_lyne config-defaults -- 'config_defaults_seed'
    assert_success
    assert_output "created kde/.config/kdeglobals
created theming/.config/qt5ct/qt5ct.conf
created theming/.config/gtk-3.0/settings.ini"
    cmp "$REPO/.data/config-defaults/kde/.config/kdeglobals" "$DOTS_DIR/kde/.config/kdeglobals"
    cmp "$REPO/.data/config-defaults/theming/.config/gtk-3.0/settings.ini" "$DOTS_DIR/theming/.config/gtk-3.0/settings.ini"
    assert_equal "$(cat "$DOTS_DIR/theming/.config/qt6ct/qt6ct.conf")" mine
    assert_equal "$(readlink "$DOTS_DIR/theming/.config/gtk-4.0/settings.ini")" nowhere
    run in_lyne config-defaults -- 'config_defaults_seed'
    assert_success
    assert_output ""
}

@test "seed: another root; a missing default fails but the others are made" {
    local root="$BATS_TEST_TMPDIR/other"
    mkdir -p "$root/.data"
    cp -r "$REPO/.data/config-defaults" "$root/.data/"
    rm "$root/.data/config-defaults/kde/.config/kdeglobals"
    run in_lyne config-defaults -- "config_defaults_seed '$root'"
    assert_failure
    assert_line "No default for kde/.config/kdeglobals in $root/.data/config-defaults"
    assert_line "created theming/.config/qt6ct/qt6ct.conf"
    refute [ -e "$root/kde/.config/kdeglobals" ]
    refute [ -e "$DOTS_DIR/theming" ]
}
