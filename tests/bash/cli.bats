#!/usr/bin/env bats
# Where the lyne CLI and the session find the repo: the CLI from its own path
# (~/.local/bin/lyne links into the repo), uwsm/env's LYNE_DOTS from its own
# link; neither needs the repo at ~/.lyne-dots nor the project's zsh

load helpers

setup() {
    lyne_setup
    # A clone somewhere else, with a migration of its own to tell it apart
    CLONE="$BATS_TEST_TMPDIR/elsewhere/dots"
    mkdir -p "$CLONE/local/.local/bin" "$CLONE/.data/lyne-cli/migrations"
    # LYNE_TEST_CLI: a copy of the CLI (to sabotage it)
    cp "${LYNE_TEST_CLI:-$REPO/local/.local/bin/lyne}" "$CLONE/local/.local/bin/lyne"
    ln -s "$REPO/.data/lyne-cli/commands" "$REPO/.data/lyne-cli/lib" "$CLONE/.data/lyne-cli/"
    ln -s "$REPO/.install" "$CLONE/"
    : >"$CLONE/.data/lyne-cli/migrations/001-only-in-the-clone.sh"
    mkdir -p "$HOME/.local/bin"
    ln -s "$CLONE/local/.local/bin/lyne" "$HOME/.local/bin/lyne"
}

# A plain bash login-less environment: no zsh, no LYNE_DOTS, only ~/.local/bin
plain() {
    env -i HOME="$HOME" PATH="$HOME/.local/bin:/usr/bin:/bin" bash -c "$1"
}

@test "the CLI finds the clone it's in, through the link, from plain bash" {
    run plain 'lyne migrate list'
    assert_success
    assert_line --partial "001-only-in-the-clone.sh"
    refute_line --partial "038-record-stowed-packages.sh"
    run plain 'lyne help'
    assert_success
    assert_line --partial "Usage: lyne <command>"
}

@test "LYNE_DOTS wins over the CLI's own path" {
    run env -i HOME="$HOME" PATH="$HOME/.local/bin:/usr/bin:/bin" LYNE_DOTS="$REPO" bash -c 'lyne migrate list'
    assert_success
    assert_line --partial "038-record-stowed-packages.sh"
}

# uwsm sources the file with sh
uwsm_env() {
    env -i HOME="$HOME" PATH=/usr/bin:/bin sh -c '. "$HOME/.config/uwsm/env" && printf "%s\n" "$LYNE_DOTS"'
}

@test "uwsm/env: LYNE_DOTS is the repo its link reaches, else ~/.lyne-dots" {
    mkdir -p "$HOME/.config/uwsm"
    ln -s "$REPO/hyprland/.config/uwsm/env" "$HOME/.config/uwsm/env"
    run uwsm_env
    assert_success
    assert_output "$(realpath "$REPO")"

    # A clone elsewhere, linked the same way
    mkdir -p "$CLONE/hyprland/.config/uwsm"
    cp "$REPO/hyprland/.config/uwsm/env" "$CLONE/hyprland/.config/uwsm/"
    ln -sfn "$CLONE/hyprland/.config/uwsm/env" "$HOME/.config/uwsm/env"
    run uwsm_env
    assert_output "$(realpath "$CLONE")"

    # Copied, not linked
    rm "$HOME/.config/uwsm/env"
    cp "$REPO/hyprland/.config/uwsm/env" "$HOME/.config/uwsm/env"
    run uwsm_env
    assert_output "$HOME/.lyne-dots"
}

@test "lyne reload and the autostart start Quickshell with 2 jemalloc arenas" {
    # Stand-ins for this test only: the real pkill would hit the user's shell
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/bash\necho "quickshell $* MALLOC_CONF=${MALLOC_CONF:-}" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/quickshell"
    printf '#!/bin/bash\necho "pkill $*" >>"$STUB_LOG"\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/pkill"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" LYNE_DOTS="$REPO" "$REPO/local/.local/bin/lyne" reload
    assert_success
    # setsid starts it in the background
    for _ in {1..50}; do grep -q '^quickshell  MALLOC' "$STUB_LOG" && break; sleep 0.1; done
    run cat "$STUB_LOG"
    assert_line "quickshell kill MALLOC_CONF="
    assert_line "pkill -KILL -x quickshell"
    assert_line "quickshell  MALLOC_CONF=narenas:2"

    run grep -F 'name = "Quickshell",        command = "env MALLOC_CONF=narenas:2 quickshell"' "$REPO/hyprland/.config/hypr/conf/autostart.lua"
    assert_success
}
