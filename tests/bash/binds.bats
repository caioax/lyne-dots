#!/usr/bin/env bats
# hypr/conf/binds.lua: how bind() and lyne_rebind() reach hl.bind/hl.unbind

load helpers

# Loads binds.lua in Lua with hl.bind/hl.unbind printed, then runs $1
run_binds() {
    lua - <<EOF
hl = {
    bind = function(keys, _, opts)
        print("bind " .. keys .. (opts and opts.release and " release" or ""))
    end,
    unbind = function(keys) print("unbind " .. keys) end,
    define_submap = function() end,
    dsp = { submap = function() end },
}
local M = dofile("$REPO/hyprland/.config/hypr/conf/binds.lua")
$1
EOF
}

@test "binds.lua: a lone modifier is bound by keycode on release, other keys as written" {
    command -v lua >/dev/null || skip "lua not installed"
    run run_binds '
M.bind("launcher", "Shell", "App launcher", "SUPER + SUPER_L", "x")
M.bind("close", "Windows", "Close", "SUPER + Q", "x")
M.bind("alt", "Shell", "Alt tap", "CTRL + ALT_R", "x")'
    assert_success
    # SUPER_L by name never matched on some keyboards (laptop, br abnt2)
    assert_line "bind SUPER + code:133 release"
    assert_line "bind SUPER + Q"
    assert_line "bind CTRL + code:108 release"
    refute_output --partial "SUPER_L"
}

@test "binds.lua: rebinding a lone modifier unbinds its keycode and Settings keeps the name" {
    command -v lua >/dev/null || skip "lua not installed"
    run run_binds '
M.bind("launcher", "Shell", "App launcher", "SUPER + SUPER_L", "x")
lyne_rebind("launcher", "SUPER + SUPER_R")
print("keys " .. LYNE_BINDS.by_id.launcher.keys)
lyne_rebind("launcher", "SUPER + SPACE")'
    assert_success
    assert_line "unbind SUPER + code:133"
    assert_line "bind SUPER + code:134 release"
    assert_line "keys SUPER + SUPER_R"
    assert_line "unbind SUPER + code:134"
    assert_line "bind SUPER + SPACE"
}
