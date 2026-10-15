#!/usr/bin/env bats
# lib/zen.sh: the lyne theme in Zen Browser profiles (fake profiles only)

load helpers

setup() {
    lyne_setup
    fake_dots
    ROOT="$HOME/.config/zen"
    P="$ROOT/abc.Default (release)"
    mkdir -p "$P" "$ROOT/def.Default Profile" "$HOME/.cache/lyne"
    cat >"$ROOT/profiles.ini" <<'EOF'
[General]
StartWithLastProfile=1

[Profile1]
Name=Default Profile
IsRelative=1
Path=def.Default Profile
Default=1

[Profile0]
Name=Default (release)
IsRelative=1
Path=abc.Default (release)

[Profile2]
Name=Gone
IsRelative=1
Path=gone.profile

[Install4F96D1932A9F858E]
Default=abc.Default (release)
EOF
    printf '[4F96D1932A9F858E]\nDefault=abc.Default (release)\nLocked=1\n' >"$ROOT/installs.ini"
    touch "$P/prefs.js"
    export LYNE_ZEN_PALETTE="$HOME/.cache/lyne/zen.json"
    jq '{palette, opacity: 0.9}' "$REPO/.data/themes/tokyonight.json" >"$LYNE_ZEN_PALETTE"
}

teardown() { repo_unchanged; }

zen() { in_lyne zen -- "$1"; }

@test "profiles: from profiles.ini, installs.ini's default, missing folders left out" {
    run zen 'zen_profiles | cut -f2,4'
    assert_success
    assert_output $'Default Profile\t0\nDefault (release)\t1'
    run zen 'zen_json'
    run jq -c '[.[] | [.name, .default, .used, .enabled, .running]]' <<<"$output"
    assert_output '[["Default Profile",false,false,false,false],["Default (release)",true,true,false,false]]'
}

@test "profiles: a legacy ~/.zen wins over the XDG folder" {
    mkdir -p "$HOME/.zen/p.old"
    printf '[Profile0]\nName=Old\nIsRelative=1\nPath=p.old\nDefault=1\n' >"$HOME/.zen/profiles.ini"
    run zen 'zen_profiles | cut -f2'
    assert_output "Old"
}

@test "enable: the CSS with the palette, imports first, the user's files backed up once" {
    mkdir -p "$P/chrome"
    echo '#nav-bar { order: 1; }' >"$P/chrome/userChrome.css"
    echo 'user_pref("browser.startup.page", 3);' >"$P/user.js"
    run zen "zen_enable '$P' && zen_enabled '$P' && echo enabled"
    assert_success
    assert_output enabled
    assert_equal "$(head -1 "$P/chrome/userChrome.css")" '@import "lyne.css"; /* lyne-dots */'
    assert_equal "$(sed -n 2p "$P/chrome/userChrome.css")" '#nav-bar { order: 1; }'
    assert_equal "$(cat "$P/chrome/userChrome.css.lyne-bak")" '#nav-bar { order: 1; }'
    grep -q '^  --lyne-background: #1a1b26;$' "$P/chrome/lyne.css"
    grep -q '^  --lyne-accent: #7aa2f7;$' "$P/chrome/lyne.css"
    grep -q '^  --lyne-scheme: dark;$' "$P/chrome/lyne.css"
    grep -q '@-moz-document url-prefix("about:")' "$P/chrome/lyne-content.css"
    run cat "$P/user.js"
    assert_line 'user_pref("browser.startup.page", 3);'
    assert_line 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    assert_line 'user_pref("zen.widget.linux.transparency", false);'
}

@test "enable and apply again change nothing" {
    run zen "zen_enable '$P'"
    local before
    before="$(snapshot)"
    run zen "zen_enable '$P' && zen_apply"
    assert_success
    assert_equal "$(snapshot)" "$before"
    refute [ -e "$P/chrome/userChrome.css.lyne-bak" ]
}

@test "options: theme background per workspace, transparency, LYNE_ZEN_OPTIONS over state.json" {
    run zen "zen_enable '$P'"
    grep -q '^  --lyne-window: #1a1b26;$' "$P/chrome/lyne.css"
    jq '.zen.transparent = true | .zen.themeBackground = false' "$HOME/.config/quickshell/state.json" >"$BATS_TEST_TMPDIR/s" &&
        mv "$BATS_TEST_TMPDIR/s" "$HOME/.config/quickshell/state.json"
    run zen 'zen_apply'
    grep -q '^  --lyne-window: color-mix(in srgb, #1a1b26 90%, transparent);$' "$P/chrome/lyne.css"
    grep -q '^:root\[zen-default-theme="true"\] {$' "$P/chrome/lyne.css"
    grep -q 'user_pref("zen.widget.linux.transparency", true);' "$P/user.js"
    run zen 'LYNE_ZEN_OPTIONS='"'"'{"transparent": false}'"'"' zen_apply'
    grep -q '^  --lyne-window: #1a1b26;$' "$P/chrome/lyne.css"
}

@test "a palette value that isn't a color never reaches the CSS" {
    jq '.palette.accent = "red; } * { display: none"' "$LYNE_ZEN_PALETTE" >"$BATS_TEST_TMPDIR/p" && mv "$BATS_TEST_TMPDIR/p" "$LYNE_ZEN_PALETTE"
    run zen "zen_enable '$P'"
    assert_failure
    refute [ -e "$P/chrome/lyne.css" ]
    refute [ -e "$P/chrome/userChrome.css" ]
}

@test "text on accent buttons: whichever of background and text reads better" {
    run zen "zen_enable '$P'"
    grep -q '^  --lyne-on-accent: #1a1b26;$' "$P/chrome/lyne.css"
    jq '.palette.accent = "#3d59a1"' "$LYNE_ZEN_PALETTE" >"$BATS_TEST_TMPDIR/p" && mv "$BATS_TEST_TMPDIR/p" "$LYNE_ZEN_PALETTE"
    run zen 'zen_apply'
    grep -q "^  --lyne-on-accent: $(jq -r .palette.text "$LYNE_ZEN_PALETTE");$" "$P/chrome/lyne.css"
}

@test "disable: back to the user's own files" {
    mkdir -p "$P/chrome"
    echo '#nav-bar { order: 1; }' >"$P/chrome/userChrome.css"
    echo 'user_pref("browser.startup.page", 3);' >"$P/user.js"
    echo 'user_pref("zen.widget.linux.transparency", true);' >>"$P/prefs.js"
    run zen "zen_enable '$P' && zen_disable '$P'"
    assert_success
    assert_equal "$(cat "$P/chrome/userChrome.css")" '#nav-bar { order: 1; }'
    refute [ -e "$P/chrome/userContent.css" ]
    refute [ -e "$P/chrome/lyne.css" ]
    assert_equal "$(cat "$P/user.js")" 'user_pref("browser.startup.page", 3);'
    refute grep -q transparency "$P/prefs.js"
    run zen "zen_enabled '$P'"
    assert_failure
}

@test "running: the profile lock points at a live Zen process" {
    cp "$(command -v sleep)" "$BATS_TEST_TMPDIR/zen-bin"
    "$BATS_TEST_TMPDIR/zen-bin" 30 &
    local pid=$!
    ln -s "127.0.0.1:+$pid" "$P/lock"
    run zen "zen_running '$P'"
    assert_success
    kill "$pid"
    wait "$pid" 2>/dev/null || true
    # A stale lock (crash) or another program's pid
    run zen "zen_running '$P'"
    assert_failure
    ln -sfn "127.0.0.1:+$$" "$P/lock"
    run zen "zen_running '$P'"
    assert_failure
}
