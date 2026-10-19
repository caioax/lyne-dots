#!/usr/bin/env bats
# default-apps.sh term: the command line each terminal gets, and --float
# (the class lyne.terminal Hyprland floats, for the terminals Settings opens)

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
