#!/usr/bin/env bats
# .install/setup/stow.sh: which packages each installer category links, and
# the targets of a package list (what goes to the backup)
# shellcheck disable=SC2030,SC2031 # each @test runs in a subshell of its own

load helpers

setup() {
    lyne_setup
    STOW_SH="${LYNE_TEST_STOW:-$REPO/.install/setup/stow.sh}"
}

# in_stow CODE: runs CODE with stow.sh sourced
in_stow() {
    bash -c 'source "$1" && eval "$2"' _ "$STOW_SH" "$1"
}

@test "stow_packages: the shell and the CLI always, the rest by category" {
    run in_stow 'stow_packages'
    assert_success
    assert_output "$(printf '%s\n' hyprland quickshell local)"

    run in_stow 'stow_packages core apps utils fonts quickshell'
    assert_output "$(printf '%s\n' hyprland quickshell local)"

    run in_stow 'stow_packages editor'
    assert_output "$(printf '%s\n' hyprland quickshell nvim local)"

    run in_stow 'stow_packages theming terminal'
    assert_output "$(printf '%s\n' hyprland quickshell kitty zsh tmux local fastfetch kde theming)"
}

@test "stow_packages: every category gives every package, in STOW_DIRS order" {
    run in_stow 'diff <(stow_packages core terminal editor apps utils fonts quickshell theming) <(printf "%s\n" "${STOW_DIRS[@]}")'
    assert_success
}

@test "stow_packages: every package named exists in the repo" {
    run in_stow 'for p in "${STOW_DIRS[@]}" "${STOW_ALWAYS[@]}" $(stow_category_packages terminal) $(stow_category_packages editor) $(stow_category_packages theming); do [[ -d "$DOTFILES_DIR/$p" ]] || echo "missing: $p"; done'
    assert_success
    assert_output ""
}

@test "stow_existing_targets: only the packages given" {
    echo mine >"$HOME/.zshrc"
    mkdir -p "$HOME/.config/nvim"
    echo mine >"$HOME/.config/nvim/init.lua"
    run in_stow 'stow_existing_targets hyprland quickshell local'
    assert_success
    assert_output ""

    run in_stow 'stow_existing_targets zsh nvim'
    assert_line "$HOME/.zshrc"
    assert_line "$HOME/.config/nvim"
}

@test "local's targets include the files of ~/.local/bin, not the folder" {
    mkdir -p "$HOME/.local/bin"
    echo mine >"$HOME/.local/bin/lyne"
    echo other >"$HOME/.local/bin/someone-elses"
    run in_stow 'stow_existing_targets local'
    assert_success
    assert_line "$HOME/.local/bin/lyne"
    refute_line --partial "someone-elses"
    refute_line "$HOME/.local/bin"
}

@test "backup_existing_targets: moves only the given packages' files" {
    echo mine >"$HOME/.zshrc"
    mkdir -p "$HOME/.config/nvim"
    echo mine >"$HOME/.config/nvim/init.lua"
    export LYNE_BACKUP_DIR="$BATS_TEST_TMPDIR/backup"
    run in_stow 'backup_existing_targets zsh'
    assert_success
    [ -f "$LYNE_BACKUP_DIR/.zshrc" ]
    [ ! -e "$HOME/.zshrc" ]
    [ -f "$HOME/.config/nvim/init.lua" ]
    [ ! -e "$LYNE_BACKUP_DIR/.config/nvim" ]
}

@test "execute_stow: one stow call per package given" {
    run in_stow 'execute_stow hyprland local'
    assert_success
    run cat "$STUB_LOG"
    assert_line "stow -d $REPO -t $HOME -R hyprland"
    assert_line "stow -d $REPO -t $HOME -R local"
    refute_line --partial " -R nvim"
    assert_equal "${#lines[@]}" 2
}

# --- packages linked ---

# Links the way stow makes them: a folder, a file, and a file inside a real
# folder (~/.local/bin); the user's own kitty folder is no link
stowed_home() {
    mkdir -p "$HOME/.config/kitty" "$HOME/.local/bin"
    echo mine >"$HOME/.config/kitty/kitty.conf"
    ln -s "$REPO/nvim/.config/nvim" "$HOME/.config/nvim"
    ln -s "$REPO/zsh/.zshrc" "$HOME/.zshrc"
    ln -s "$REPO/local/.local/bin/lyne" "$HOME/.local/bin/lyne"
}

@test "stow_linked_packages: the packages HOME reaches through links" {
    stowed_home
    run in_stow 'stow_linked_packages'
    assert_success
    assert_output "$(printf '%s\n' nvim zsh local)"
}

@test "stow_recorded_packages: the record, or what's linked when there is none" {
    stowed_home
    export LYNE_STATE_FILE="$BATS_TEST_TMPDIR/state.json"
    # No state.json, then a null record: what's linked
    run in_stow 'stow_recorded_packages'
    assert_output "$(printf '%s\n' nvim zsh local)"
    echo '{"system": {"stow": null}}' >"$LYNE_STATE_FILE"
    run in_stow 'stow_recorded_packages'
    assert_output "$(printf '%s\n' nvim zsh local)"
    # A record wins, even an empty one
    echo '{"system": {"stow": ["hyprland", "kitty"]}}' >"$LYNE_STATE_FILE"
    run in_stow 'stow_recorded_packages'
    assert_output "$(printf '%s\n' hyprland kitty)"
    run in_stow 'stow_is_linked kitty'
    assert_success
    run in_stow 'stow_is_linked nvim'
    assert_failure
    echo '{"system": {"stow": []}}' >"$LYNE_STATE_FILE"
    run in_stow 'stow_recorded_packages'
    assert_output ""
}

@test "stow_record and stow_default_packages: the record plus the shell's" {
    export LYNE_STATE_FILE="$BATS_TEST_TMPDIR/state.json"
    echo '{"system": {"stow": null, "editor": "nvim"}}' >"$LYNE_STATE_FILE"
    run in_stow 'stow_record nvim local'
    assert_success
    assert_equal "$(jq -c .system "$LYNE_STATE_FILE")" '{"stow":["nvim","local"],"editor":"nvim"}'
    run in_stow 'stow_default_packages'
    assert_output "$(printf '%s\n' hyprland quickshell nvim local)"
    echo '{"system": {"stow": []}}' >"$LYNE_STATE_FILE"
    run in_stow 'stow_default_packages'
    assert_output "$(printf '%s\n' hyprland quickshell local)"
}
