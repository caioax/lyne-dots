#!/usr/bin/env bats
# default-apps.sh term: the command line each terminal gets, and --float
# (the class lyne.terminal Hyprland floats, for the terminals Settings opens);
# apply: the hidden lyne-<slot>.desktop of terminal apps and its name and icon;
# refresh: only the slots that have one

load helpers

setup() {
    lyne_setup
    # LYNE_TEST_DEFAULT_APPS points the tests at another copy of the script
    SCRIPT="${LYNE_TEST_DEFAULT_APPS:-$REPO/quickshell/.config/quickshell/scripts/default-apps.sh}"
    # Terminals that print how they were called
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN" "$HOME/.config/quickshell"
    local t
    for t in kitty foot alacritty wezterm ghostty konsole; do
        printf '#!/bin/bash\necho "%s $*"\n' "$t" >"$BIN/$t"
        chmod +x "$BIN/$t"
    done
    export PATH="$BIN:$PATH"
}

# terminal COMMAND: the default terminal in state.json
terminal() {
    jq -n --arg t "$1" '{apps: {terminal: {command: $t}}}' >"$HOME/.config/quickshell/state.json"
}

@test "term runs the command in the default terminal, its own way" {
    terminal kitty
    run "$SCRIPT" term bash -c "echo hi"
    assert_output "kitty -e bash -c echo hi"
    terminal foot
    run "$SCRIPT" term htop
    assert_output "foot htop"
    terminal "wezterm --config x"
    run "$SCRIPT" term htop
    assert_output "wezterm --config x start -- htop"
}

@test "term --float gives each terminal the lyne.terminal class" {
    terminal kitty
    run "$SCRIPT" term --float bash -c "echo hi"
    assert_output "kitty --class=lyne.terminal -e bash -c echo hi"
    terminal alacritty
    run "$SCRIPT" term --float htop
    assert_output "alacritty --class=lyne.terminal -e htop"
    terminal ghostty
    run "$SCRIPT" term --float htop
    assert_output "ghostty --class=lyne.terminal -e htop"
    terminal foot
    run "$SCRIPT" term --float htop
    assert_output "foot --app-id=lyne.terminal htop"
    terminal "wezterm --config x"
    run "$SCRIPT" term --float htop
    assert_output "wezterm --config x start --class lyne.terminal -- htop"
}

@test "term --float in a terminal without a class flag opens it as usual" {
    terminal konsole
    run "$SCRIPT" term --float htop
    assert_output "konsole -e htop"
}

@test "Hyprland floats the lyne.terminal class" {
    run grep -A3 'name  = "lyne-terminal-float"' "$REPO/hyprland/.config/hypr/conf/rules.lua"
    assert_output --partial 'class = "^(lyne\\.terminal)$"'
}

# A system applications dir with the .desktop files of a few apps
apps_dir() {
    local dir="$BATS_TEST_TMPDIR/share/applications"
    mkdir -p "$dir"
    printf '%s\n' '[Desktop Entry]' 'Name=Neovim' 'Name[pt_BR]=Neovim BR' 'Icon=nvim' 'Exec=nvim %F' 'Terminal=true' \
        'MimeType=text/plain;' '[Desktop Action new]' 'Name=New file' 'Icon=other' >"$dir/nvim.desktop"
    printf '%s\n' '[Desktop Entry]' 'Name=kitty' 'Icon=kitty' 'Exec=kitty' >"$dir/kitty.desktop"
    printf '%s\n' '[Desktop Entry]' 'Name=Dolphin' 'Icon=system-file-manager' 'Exec=dolphin %u' >"$dir/org.kde.dolphin.desktop"
    export XDG_DATA_DIRS="$BATS_TEST_TMPDIR/share"
    WRAPPER="$HOME/.local/share/applications/lyne-editor.desktop"
}

@test "apply: a terminal editor gets a wrapper with the app's name and icon" {
    apps_dir
    terminal kitty
    run "$SCRIPT" apply editor nvim
    assert_success
    run cat "$WRAPPER"
    assert_line "Name=Neovim (lyne editor)"
    assert_line "Icon=nvim"
    assert_line "Exec=$(realpath "$SCRIPT") term nvim %F"
    assert_line "NoDisplay=true"
    assert_line "MimeType=text/plain;"
    run grep -c "lyne-editor.desktop text/plain" "$STUB_LOG"
    assert_output 1
}

@test "apply: a terminal app without a .desktop file gets the terminal's icon" {
    apps_dir
    terminal kitty
    run "$SCRIPT" apply editor micro "" 1
    assert_success
    run cat "$WRAPPER"
    assert_line "Name=micro (lyne editor)"
    assert_line "Icon=kitty"
}

@test "apply: a GUI command without a .desktop file has no icon line" {
    apps_dir
    run "$SCRIPT" apply editor "mousepad --x" "" 0
    assert_success
    run cat "$WRAPPER"
    assert_line "Name=mousepad --x (lyne editor)"
    assert_line "Exec=mousepad --x %F"
    refute_line --partial "Icon="
}

@test "apply: an app with its own .desktop file needs no wrapper" {
    apps_dir
    run "$SCRIPT" apply fileManager dolphin org.kde.dolphin
    assert_success
    [[ ! -e "$HOME/.local/share/applications/lyne-fileManager.desktop" ]]
    run grep "org.kde.dolphin.desktop inode/directory" "$STUB_LOG"
    assert_success
}

@test "refresh rewrites an old wrapper and leaves the other slots alone" {
    apps_dir
    jq -n '{apps: {terminal: {command: "kitty"}, browser: {command: "firefox"}}, system: {editor: "nvim"}}' \
        >"$HOME/.config/quickshell/state.json"
    mkdir -p "$(dirname "$WRAPPER")"
    printf '%s\n' '[Desktop Entry]' 'Name=nvim (lyne editor)' 'Exec=old term nvim %F' >"$WRAPPER"
    run "$SCRIPT" refresh
    assert_success
    run cat "$WRAPPER"
    assert_line "Icon=nvim"
    run grep -c "default" "$STUB_LOG"
    assert_output 1
}

@test "refresh with no wrappers changes nothing" {
    apps_dir
    run "$SCRIPT" refresh
    assert_success
    [[ ! -s "$STUB_LOG" ]]
}
