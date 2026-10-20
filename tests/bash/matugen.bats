#!/usr/bin/env bats
# .data/matugen/config.toml: its templates are found wherever the repo is
# (paths relative to the config, which matugen resolves through its link)

load helpers

setup() {
    lyne_setup
    CONFIG="${LYNE_TEST_MATUGEN:-$REPO/.data/matugen}/config.toml"
}

@test "every template's input is a relative path to a file next to the config" {
    local inputs path
    mapfile -t inputs < <(sed -nE 's/^input_path = "(.*)"$/\1/p' "$CONFIG")
    assert [ "${#inputs[@]}" -gt 0 ]
    for path in "${inputs[@]}"; do
        [[ "$path" != /* && "$path" != "~"* && "$path" != *'$'* ]] || fail "not relative: $path"
        [[ -f "$(dirname "$CONFIG")/$path" ]] || fail "missing: $path"
    done
}

@test "matugen renders every template through a link, from another folder" {
    command -v matugen >/dev/null || skip "matugen isn't installed"
    # A copy of the folder with its outputs in the test dir, linked the way
    # the installer links ~/.config/matugen/config.toml
    local dir="$BATS_TEST_TMPDIR/dots/.data/matugen" out="$BATS_TEST_TMPDIR/out"
    mkdir -p "$(dirname "$dir")" "$out" "$HOME/.config/matugen"
    cp -r "$(dirname "$CONFIG")" "$dir"
    sed -i "s|^output_path = \"~/.cache/matugen/|output_path = \"$out/|" "$dir/config.toml"
    ln -s "$dir/config.toml" "$HOME/.config/matugen/config.toml"
    cd /
    run matugen color hex "#336699" -c "$HOME/.config/matugen/config.toml"
    assert_success
    local name
    for name in quickshell-palette hyprland-colors terminal-colors; do
        jq -e . "$out/$name.json" >/dev/null || fail "$name.json not rendered"
    done
}
