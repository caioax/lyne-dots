#!/usr/bin/env bats
# lib/state.sh (atomic state.json writes) and lib/sync-state.sh (merge with
# defaults.json)

load helpers

setup() {
    lyne_setup
    # The real layout: ~/.config/quickshell links into the repo
    CFG="$DOTS_DIR/quickshell/.config/quickshell"
    mkdir -p "$CFG" "$DOTS_DIR/.data/quickshell" "$HOME/.config"
    ln -s "$CFG" "$HOME/.config/quickshell"
    STATE="$CFG/state.json"
    DEFAULTS="$DOTS_DIR/.data/quickshell/defaults.json"
    echo '{"theme": {"name": "nord"}, "n": 1}' >"$STATE"
}

inode() { stat -c %i "$STATE"; }

@test "set: one jq filter, written through the symlink by a rename" {
    local before
    before="$(inode)"
    run in_lyne -- 'lyne_state_set ".theme.name = \$n | .n += 1" --arg n tokyonight'
    assert_success
    assert_equal "$(jq -c . "$STATE")" '{"theme":{"name":"tokyonight"},"n":2}'
    assert [ "$(inode)" != "$before" ]
    assert [ -L "$HOME/.config/quickshell" ]
    run ls -A "$CFG"
    assert_output "state.json"
}

@test "set: a write that changes nothing leaves the file alone" {
    jq . "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    local before
    before="$(inode)"
    run in_lyne -- 'lyne_state_set ".n = 1"'
    assert_success
    assert_equal "$(inode)" "$before"
}

@test "set: a jq error or a missing file changes nothing and fails" {
    local before
    before="$(inode)"
    run in_lyne -- 'lyne_state_set ".n = (" 2>/dev/null'
    assert_failure
    assert_equal "$(inode)" "$before"
    assert_equal "$(jq -c . "$STATE")" '{"theme":{"name":"nord"},"n":1}'
    run in_lyne -- 'LYNE_STATE_FILE=$HOME/none.json lyne_state_set ".n = 2"'
    assert_failure
    refute [ -e "$HOME/none.json" ]
}

@test "replace: keeps the permissions; empty input keeps the file" {
    # Not mktemp's 600: the copy must take the original's mode
    chmod 640 "$STATE"
    run in_lyne -- 'echo "{\"x\": 1}" | lyne_state_replace'
    assert_success
    assert_equal "$(cat "$STATE")" '{"x": 1}'
    assert_equal "$(stat -c %a "$STATE")" 640
    run in_lyne -- 'lyne_state_replace </dev/null'
    assert_success
    assert_equal "$(cat "$STATE")" '{"x": 1}'
}

sync() { in_lyne sync-state -- ''; }

@test "sync: no state.json yet = a copy of the defaults" {
    rm "$STATE"
    echo '{"a": 1}' >"$DEFAULTS"
    run sync
    assert_success
    assert_output --partial "created state.json from defaults"
    assert_equal "$(cat "$STATE")" '{"a": 1}'
}

@test "sync: defaults give the shape, the user's values stay when their type still fits" {
    cat >"$DEFAULTS" <<'EOF'
{"bar": {"autoHide": false, "height": 32, "modules": ["clock"], "font": null},
 "launcher": {"rows": 7, "style": "spotlight"}, "newKey": {"on": true}}
EOF
    cat >"$STATE" <<'EOF'
{"bar": {"autoHide": true, "height": "big", "modules": ["tray", "clock"], "font": "Inter"},
 "launcher": {"rows": 9}, "removed": {"x": 1}}
EOF
    run sync
    assert_success
    assert_output --partial "synced with defaults"
    run jq -c . "$STATE"
    # false default with true kept, wrong type reset, whole array kept, null
    # default takes anything, missing keys filled, unknown keys dropped
    assert_output '{"bar":{"autoHide":true,"height":32,"modules":["tray","clock"],"font":"Inter"},"launcher":{"rows":9,"style":"spotlight"},"newKey":{"on":true}}'
}

@test "sync: launcher.terminal moves to apps.terminal" {
    cp "$REPO/.data/quickshell/defaults.json" "$DEFAULTS"
    echo '{"launcher": {"terminal": "alacritty"}}' >"$STATE"
    run sync
    assert_success
    assert_equal "$(jq -c .apps.terminal "$STATE")" '{"command":"alacritty","desktop":""}'
    assert_equal "$(jq -r '.launcher.terminal // "gone"' "$STATE")" gone
    # An apps.terminal the user already has wins
    echo '{"launcher": {"terminal": "alacritty"}, "apps": {"terminal": {"command": "foot", "desktop": "foot"}}}' >"$STATE"
    run sync
    assert_equal "$(jq -c .apps.terminal "$STATE")" '{"command":"foot","desktop":"foot"}'
}

@test "sync: the real defaults.json synced over itself is unchanged" {
    cp "$REPO/.data/quickshell/defaults.json" "$DEFAULTS"
    cp "$DEFAULTS" "$STATE"
    local before
    run sync
    assert_success
    assert_equal "$(jq -S . "$STATE")" "$(jq -S . "$DEFAULTS")"
    # jq reformats the file once; a second sync writes nothing
    before="$(inode)"
    run sync
    assert_equal "$(inode)" "$before"
}

@test "sync: missing defaults.json fails" {
    run sync
    assert_failure
    assert_output --partial "defaults.json not found"
}
