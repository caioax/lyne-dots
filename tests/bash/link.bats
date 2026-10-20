#!/usr/bin/env bats
# lyne link / lyne unlink with the real GNU Stow, on $DOTS_DIR made of copies
# of the packages (links into the repo would let stow's links write there)
# shellcheck disable=SC2088 # the "~/..." are the text the commands print

load helpers

setup() {
    lyne_setup
    # The real stow, not the logging stand-in
    local stow
    stow="$(PATH="${PATH//"$BATS_TEST_DIRNAME/stubs:"/}" command -v stow)" || skip "GNU Stow isn't installed"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    ln -s "$stow" "$BATS_TEST_TMPDIR/bin/stow"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

    mkdir -p "$DOTS_DIR"
    # LYNE_TEST_INSTALL: a copy of .install (to sabotage stow.sh)
    ln -s "${LYNE_TEST_INSTALL:-$REPO/.install}" "$DOTS_DIR/.install"
    ln -s "$REPO/.data" "$DOTS_DIR/"
    local pkg
    for pkg in hyprland kitty nvim zsh tmux fastfetch kde theming; do
        cp -r "$REPO/$pkg" "$DOTS_DIR/"
    done
    # The big ones as stand-ins
    mkdir -p "$DOTS_DIR/quickshell/.config/quickshell" "$DOTS_DIR/local/.local/bin"
    : >"$DOTS_DIR/quickshell/.config/quickshell/shell.qml"
    cp "$REPO/local/.local/bin/lyne" "$DOTS_DIR/local/.local/bin/"

    export LYNE_STATE_FILE="$BATS_TEST_TMPDIR/state.json"
    echo '{"system": {"stow": ["hyprland", "quickshell", "local"]}}' >"$LYNE_STATE_FILE"
    # shellcheck disable=SC2034 # read by repo_unchanged
    REPO_STATUS="$(git -C "$REPO" status --porcelain)"
}

teardown() { repo_unchanged; }

lyne() { "$REPO/local/.local/bin/lyne" "$@"; }
recorded() { jq -c .system.stow "$LYNE_STATE_FILE"; }

@test "status: each package, linked or not, its category and targets" {
    run lyne link
    assert_success
    assert_line --regexp '^  (●|\S) hyprland +always +~/\.config/hypr, ~/\.config/uwsm$'
    assert_line --regexp '^  ○ nvim +editor +~/\.config/nvim$'
    assert_line --regexp '^  ○ zsh +terminal +~/\.zshrc, ~/\.p10k\.zsh$'
    assert_line --regexp '^  ○ kde +theming +~/\.config/kdeglobals$'
    assert_equal "${#lines[@]}" 10
}

@test "link: the user's files to the backup, the links made, the record kept" {
    echo mine >"$HOME/.zshrc"
    run lyne link nvim zsh
    assert_success
    assert_output --partial "Moved to the backup: ~/.zshrc"
    assert_output --partial "~/.zshrc needs Oh My Zsh"
    [ "$(realpath "$HOME/.zshrc")" == "$(realpath "$DOTS_DIR/zsh/.zshrc")" ]
    [ "$(realpath "$HOME/.config/nvim")" == "$(realpath "$DOTS_DIR/nvim/.config/nvim")" ]
    run find "$HOME/.lyne-dots-backup" -name .zshrc
    assert_output --regexp '/\.lyne-dots-backup/[0-9]{8}-[0-9]{6}/\.zshrc$'
    assert_equal "$(recorded)" '["hyprland","quickshell","nvim","zsh","local"]'
}

@test "unlink: the links go, the newest backup comes back, the record follows" {
    mkdir -p "$HOME/.lyne-dots-backup/20260101-000000" "$HOME/.lyne-dots-backup/20260202-000000"
    echo older >"$HOME/.lyne-dots-backup/20260101-000000/.zshrc"
    echo newer >"$HOME/.lyne-dots-backup/20260202-000000/.zshrc"
    lyne link zsh nvim
    run lyne unlink zsh nvim
    assert_success
    assert_output --partial "Restored ~/.zshrc from ~/.lyne-dots-backup/20260202-000000/.zshrc"
    refute [ -L "$HOME/.zshrc" ]
    assert_equal "$(cat "$HOME/.zshrc")" newer
    # No backup of these: only the links go
    refute [ -e "$HOME/.p10k.zsh" ]
    refute [ -e "$HOME/.config/nvim" ]
    assert [ -f "$HOME/.lyne-dots-backup/20260101-000000/.zshrc" ]
    assert_equal "$(recorded)" '["hyprland","quickshell","local"]'
}

@test "refused: unknown packages, the shell's own, one not linked" {
    run lyne link nope
    assert_failure
    assert_output --partial "unknown package 'nope'"
    run lyne unlink quickshell
    assert_failure
    assert_output --partial "quickshell is always linked"
    run lyne unlink kitty
    assert_failure
    assert_output --partial "kitty isn't linked"
    run lyne unlink
    assert_failure
    assert_output --partial "Usage: lyne unlink"
    assert_equal "$(recorded)" '["hyprland","quickshell","local"]'
}
