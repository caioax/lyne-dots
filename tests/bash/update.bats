#!/usr/bin/env bats
# lib/channel.sh (where lyne update goes) and lib/managed-files.sh (files the
# update puts back), on throwaway git repos: origin.git, a work clone that
# publishes, and $DOTS_DIR, the user's clone

load helpers

setup() {
    lyne_setup
    export LYNE_STATE_FILE="$HOME/state.json"
    echo '{}' >"$LYNE_STATE_FILE"
    ORIGIN="$BATS_TEST_TMPDIR/origin.git"
    WORK="$BATS_TEST_TMPDIR/work"
    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$WORK" 2>/dev/null
}

# publish NAME [TAG [NOTES]]: a commit on the work clone's branch, pushed
publish() {
    echo "$1" >>"$WORK/history"
    git -C "$WORK" add -A
    git -C "$WORK" commit -qm "$1"
    [[ -n "${2:-}" ]] && git -C "$WORK" tag -a "$2" -m "${3:-Release $2}"
    git -C "$WORK" push -q --follow-tags origin HEAD 2>/dev/null
}

user_clone() { git clone -q "$ORIGIN" "$DOTS_DIR" 2>/dev/null; }
fetch() { git -C "$DOTS_DIR" fetch -q --tags origin; }

resolve() { in_lyne channel -- "channel_resolve ${1:-stable}; echo \"\$CH_FOLLOWS|\$CH_TARGET_NAME|\$CH_LAST_RELEASE|\$CH_BEHIND\""; }

@test "channel_get: argument, then update.channel, then stable" {
    run in_lyne channel -- 'channel_get latest'
    assert_output latest
    run in_lyne channel -- 'channel_get'
    assert_output stable
    echo '{"update": {"channel": "latest"}}' >"$LYNE_STATE_FILE"
    run in_lyne channel -- 'channel_get'
    assert_output latest
    run in_lyne channel -- 'channel_get nightly'
    assert_failure
    assert_output --partial "unknown channel 'nightly'"
}

@test "stable follows the newest release tag; latest the tip of main" {
    publish one v1.0.0
    user_clone
    publish two
    publish three v1.1.0
    publish four
    publish rc v1.2.0-rc1
    fetch
    run resolve stable
    assert_output "channel|v1.1.0|v1.1.0|2"
    run resolve latest
    assert_output "channel|origin/main|v1.1.0|4"
}

@test "stable never goes back: past the last release, nothing to do" {
    publish one v1.0.0
    publish two
    user_clone
    run resolve stable
    assert_output "channel|v1.0.0|v1.0.0|0"
}

@test "stable without any release has no target; no upstream neither" {
    publish one
    user_clone
    run resolve stable
    assert_output "channel|||0"
    git -C "$DOTS_DIR" branch -q --unset-upstream
    run resolve latest
    assert_output "channel|||0"
}

@test "another branch follows its upstream whatever the channel" {
    publish one v1.0.0
    git -C "$WORK" checkout -qb dev
    publish wip
    user_clone
    git -C "$DOTS_DIR" checkout -q -b dev origin/dev 2>/dev/null
    git -C "$DOTS_DIR" reset -q --hard HEAD~1
    run resolve stable
    assert_output "branch|origin/dev|v1.0.0|1"
}

@test "version: the last release, +N past it, nothing before the first" {
    publish one
    user_clone
    run in_lyne channel -- 'channel_version'
    assert_output ""
    publish two v1.0.0
    publish three
    publish four
    fetch
    git -C "$DOTS_DIR" merge -q --ff-only origin/main
    run in_lyne channel -- 'channel_version'
    assert_output "v1.0.0+2"
    git -C "$DOTS_DIR" checkout -q v1.0.0 2>/dev/null
    run in_lyne channel -- 'channel_version'
    assert_output "v1.0.0"
}

@test "release notes: the releases HEAD has and the old commit didn't, newest first" {
    publish one v1.0.0 "First"
    publish two v1.1.0 $'Second\n\n- a fix'
    publish three v1.2.0-rc1
    publish four v1.2.0 "Third"
    user_clone
    run in_lyne channel -- 'channel_notes_json v1.0.0'
    assert_success
    run jq -c '[.[] | [.version, .notes]]' <<<"$output"
    assert_output '[["v1.2.0","Third"],["v1.1.0","Second\n\n- a fix"]]'
    run in_lyne channel -- 'channel_notes_json | jq length'
    assert_output 3
}

# --- managed files ---

managed_repo() {
    mkdir -p "$WORK/nvim/.config/nvim" "$WORK/kde/.config"
    echo '{"lazy": "v1"}' >"$WORK/nvim/.config/nvim/lazy-lock.json"
    echo '[General]' >"$WORK/kde/.config/kdeglobals"
    publish base
    user_clone
}

LOCK=nvim/.config/nvim/lazy-lock.json
KDE=kde/.config/kdeglobals

@test "managed files don't count as uncommitted changes" {
    managed_repo
    echo '{"lazy": "mine"}' >"$DOTS_DIR/$LOCK"
    echo 'TerminalApplication=foot' >>"$DOTS_DIR/$KDE"
    run in_lyne managed-files -- 'git -C "$DOTS_DIR" status --porcelain -- . "${MANAGED_EXCLUDES[@]}"'
    assert_output ""
    echo x >"$DOTS_DIR/history"
    run in_lyne managed-files -- 'git -C "$DOTS_DIR" status --porcelain -- . "${MANAGED_EXCLUDES[@]}"'
    assert_output " M history"
}

# Saves, pulls origin/main (fast-forward) and restores, like lyne update
update() {
    in_lyne managed-files -- '
        old=$(git -C "$DOTS_DIR" rev-parse HEAD)
        managed_save || exit 1
        git -C "$DOTS_DIR" status --porcelain
        git -C "$DOTS_DIR" pull -q --ff-only 2>/dev/null || exit 1
        managed_restore "$old"'
}

@test "update: the user's copies come back when the update doesn't touch them" {
    managed_repo
    echo '{"lazy": "mine"}' >"$DOTS_DIR/$LOCK"
    echo 'TerminalApplication=foot' >>"$DOTS_DIR/$KDE"
    publish unrelated
    run update
    assert_success
    # Nothing left in the tree while pulling
    refute_output --partial " M "
    assert_equal "$(cat "$DOTS_DIR/$LOCK")" '{"lazy": "mine"}'
    assert_equal "$(tail -1 "$DOTS_DIR/$KDE")" 'TerminalApplication=foot'
    assert_equal "$(tail -1 "$DOTS_DIR/history")" unrelated
}

@test "update: a new lazy-lock wins (the user's goes to the backup); kdeglobals always stays" {
    managed_repo
    echo '{"lazy": "mine"}' >"$DOTS_DIR/$LOCK"
    echo 'TerminalApplication=foot' >>"$DOTS_DIR/$KDE"
    echo '{"lazy": "v2"}' >"$WORK/$LOCK"
    echo '[Icons]' >>"$WORK/$KDE"
    publish "new pins"
    run update
    assert_success
    assert_output --partial "$LOCK: the update brings a new version, yours is in $HOME/.local/share/lyne/backup/lazy-lock.json."
    assert_equal "$(cat "$DOTS_DIR/$LOCK")" '{"lazy": "v2"}'
    assert_equal "$(cat "$HOME"/.local/share/lyne/backup/lazy-lock.json.*)" '{"lazy": "mine"}'
    assert_equal "$(tail -1 "$DOTS_DIR/$KDE")" 'TerminalApplication=foot'
}

@test "update: unchanged managed files aren't copied around" {
    managed_repo
    run in_lyne managed-files -- 'managed_save; echo "saved=${#MANAGED_SAVED[@]} dir=$MANAGED_SAVE_DIR"'
    assert_output "saved=0 dir="
}
