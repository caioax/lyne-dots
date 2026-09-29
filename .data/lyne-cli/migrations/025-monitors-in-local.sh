# 025-monitors-in-local.sh - monitors.lua moves to hypr/local/
#
# Settings › Hyprland › Monitors writes ~/.config/hypr/local/monitors.lua,
# next to the other machine-specific files (hyprland.lua loads every
# local/*.lua). The monitors.lua in ~/.config/hypr only stayed there for
# nwg-displays: it moves to local/, or aside as monitors.lua.old when
# local/ already has one. hyprland.lua keeps reading the old place while
# local/monitors.lua is missing, so the monitors don't change meanwhile.

local hypr_dir="$HOME/.config/hypr"
local old="$hypr_dir/monitors.lua"
local new="$hypr_dir/local/monitors.lua"

if [[ -f "$old" ]]; then
    mkdir -p "$hypr_dir/local"
    if [[ -f "$new" ]]; then
        mv -f "$old" "$old.old"
        echo "   Monitors live in hypr/local/monitors.lua; the old hypr/monitors.lua is now monitors.lua.old"
    else
        mv "$old" "$new"
        echo "   Moved hypr/monitors.lua to hypr/local/monitors.lua (Settings › Hyprland › Monitors)"
    fi
fi
