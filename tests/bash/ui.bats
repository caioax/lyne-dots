#!/usr/bin/env bats
# .install/lib/ui.sh and ask.sh: text wrapping and the review screen's rows
# (built into UI_LINES, nothing drawn)
# shellcheck disable=SC2088 # the "~/..." are the text the screen shows

load helpers

setup() {
    lyne_setup
    INSTALL_LIB="${LYNE_TEST_INSTALL_LIB:-$REPO/.install/lib}"
}

# in_ui CODE: runs CODE with ui.sh and ask.sh sourced, plain glyphs and
# UI_WIDTH 40
in_ui() {
    LYNE_ASCII=1 bash -c '
        source "$1/ui.sh" && source "$1/ask.sh"
        ui_setup
        UI_WIDTH=40
        C_BOLD="" C_RESET=""
        eval "$2"' _ "$INSTALL_LIB" "$1"
}

@test "ui_wrap: breaks between words, never past the width" {
    run in_ui 'ui_wrap "~/.zshrc, ~/.p10k.zsh, ~/.config/nvim, ~/.config/kitty, ~/.tmux.conf" 20'
    assert_success
    assert_line --index 0 "~/.zshrc,"
    assert_line --index 1 "~/.p10k.zsh,"
    assert_line --index 2 "~/.config/nvim,"
    assert_line --index 3 "~/.config/kitty,"
    assert_line --index 4 "~/.tmux.conf"
    local line
    for line in "${lines[@]}"; do
        ((${#line} <= 20))
    done
}

@test "ui_wrap: keeps the text's own line breaks, cuts a word too long" {
    run in_ui 'ui_wrap "$(printf "a b\nto ~/.lyne-dots-backup/20261020-120000")" 12'
    assert_success
    assert_line --index 0 "a b"
    assert_line --index 1 "to"
    # Fitted with the ASCII ellipsis
    assert_line --index 2 "~/.lyne-d..."
    assert_equal "${#lines[@]}" 3
}

@test "review rows: a long value wraps under its key, a short one stays on one line" {
    run in_ui '_ask_review_rows "Links|hyprland, quickshell, kitty, nvim, zsh, tmux, local" "Reboot|no"
        printf "%s\n" "${UI_LINES[@]}"'
    assert_success
    # 2 spaces of margin, then the key padded to 11
    assert_line --index 0 "  Links      hyprland, quickshell, kitty,"
    assert_line --index 1 "             nvim, zsh, tmux, local"
    assert_line --index 2 "  Reboot     no"
    assert_equal "${#lines[@]}" 3
}
