#!/usr/bin/env bats
# bootstrap.sh (curl ... | bash): clones a throwaway origin.git into the fake
# HOME, at its newest release, and runs that release's install.sh (here a
# stand-in that logs where it ran and with what)

load helpers

setup() {
    lyne_setup
    export LYNE_STATE_FILE="$HOME/state.json"
    echo '{}' >"$LYNE_STATE_FILE"
    ORIGIN="$BATS_TEST_TMPDIR/origin.git"
    WORK="$BATS_TEST_TMPDIR/work"
    INSTALL_LOG="$BATS_TEST_TMPDIR/install.log"
    export LYNE_BOOTSTRAP_REPO="$ORIGIN" INSTALL_LOG
    # LYNE_TEST_BOOTSTRAP points the tests at another copy of the script
    BOOTSTRAP="${LYNE_TEST_BOOTSTRAP:-$REPO/bootstrap.sh}"
    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$WORK" 2>/dev/null
}

# publish NAME [TAG]: a commit whose install.sh logs NAME, pushed (tagged)
publish() {
    printf '#!/bin/bash\necho "%s|$(git rev-parse --abbrev-ref HEAD)|$*" >>"$INSTALL_LOG"\n' "$1" >"$WORK/install.sh"
    chmod +x "$WORK/install.sh"
    git -C "$WORK" add -A
    git -C "$WORK" commit -qm "$1"
    [[ -n "${2:-}" ]] && git -C "$WORK" tag -a "$2" -m "Release $2"
    git -C "$WORK" push -q --follow-tags origin HEAD 2>/dev/null
}

# The way the README runs it: the script on stdin
bootstrap() { bash -s -- "$@" <"$BOOTSTRAP"; }

@test "installs the latest release: main at the tag, still tracking origin/main" {
    publish one v1.0.0
    publish two v1.1.0
    publish three
    publish four
    run bootstrap --dry-run --answers a
    assert_success
    assert_output --partial "Installing lyne-dots v1.1.0 (the latest release)"
    # The release's install.sh ran, on main, with the arguments
    run cat "$INSTALL_LOG"
    assert_output "two|main|--dry-run --answers a"
    assert_equal "$(git -C "$DOTS_DIR" rev-parse HEAD)" "$(git -C "$WORK" rev-parse 'v1.1.0^{commit}')"
    assert_equal "$(git -C "$DOTS_DIR" rev-parse --abbrev-ref '@{u}')" "origin/main"
    assert_equal "$(git -C "$DOTS_DIR" status --porcelain)" ""
    # lyne update from there: stable is at its release, latest two behind
    run in_lyne channel -- 'channel_resolve stable; echo "$CH_TARGET_NAME|$CH_BEHIND"; channel_resolve latest; echo "$CH_TARGET_NAME|$CH_BEHIND"; channel_version'
    assert_output $'v1.1.0|0\norigin/main|2\nv1.1.0'
}

@test "the newest release by version, only on main, no pre-releases" {
    publish one v1.9.0
    publish two v1.10.0
    publish three v2.0.0-rc1
    git -C "$WORK" switch -q -c side
    publish side v3.0.0
    run bootstrap
    assert_success
    assert_output --partial "Installing lyne-dots v1.10.0"
    run cat "$INSTALL_LOG"
    assert_output "two|main|"
}

@test "no release yet: the tip of main" {
    publish one
    publish two
    run bootstrap
    assert_success
    assert_output --partial "No release yet"
    run cat "$INSTALL_LOG"
    assert_output "two|main|"
}

@test "an existing ~/.lyne-dots is left alone and nothing is installed" {
    publish one v1.0.0
    mkdir -p "$DOTS_DIR"
    echo mine >"$DOTS_DIR/file"
    run bootstrap
    assert_failure
    assert_output --partial "\`lyne update\` updates it"
    assert_equal "$(ls -A "$DOTS_DIR")" "file"
    [[ ! -e "$INSTALL_LOG" ]]
    # An empty one (git would clone into it) and a dangling link count too
    rm -rf "$DOTS_DIR"
    mkdir "$DOTS_DIR"
    run bootstrap
    assert_failure
    assert_output --partial "\`lyne update\` updates it"
    assert_equal "$(ls -A "$DOTS_DIR")" ""
    rmdir "$DOTS_DIR"
    ln -s "$BATS_TEST_TMPDIR/nowhere" "$DOTS_DIR"
    run bootstrap
    assert_failure
    assert_output --partial "\`lyne update\` updates it"
    [[ ! -e "$INSTALL_LOG" ]]
}

@test "a failed clone stops before the installer" {
    LYNE_BOOTSTRAP_REPO="$BATS_TEST_TMPDIR/missing.git" run bootstrap
    assert_failure
    assert_output --partial "couldn't clone"
    [[ ! -e "$DOTS_DIR" && ! -e "$INSTALL_LOG" ]]
}

@test "a script cut short runs nothing" {
    publish one v1.0.0
    # Everything but the last line (the call to main)
    run bash -s < <(sed '$d' "$BOOTSTRAP")
    assert_success
    [[ ! -e "$DOTS_DIR" && ! -e "$INSTALL_LOG" ]]
}
