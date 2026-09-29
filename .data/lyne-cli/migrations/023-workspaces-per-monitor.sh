# 023-workspaces-per-monitor.sh - Workspaces per monitor moved into Hyprland
#
# conf/workspaces.lua now gives each monitor its block of workspaces and
# remembers it, also while the monitor is disconnected, in
# ~/.local/state/lyne/workspace-monitors.lua. workspace-manager.sh and the
# ~/.config/hypr/workspaces.lua it generated are gone; the monitors of that
# file keep their blocks.

old="$HOME/.config/hypr/workspaces.lua"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/lyne"
state="$state_dir/workspace-monitors.lua"

if [[ -f "$old" ]]; then
    mkdir -p "$state_dir"

    # Hyprland may have written the state already (config reloaded by the
    # update): only add the monitors it doesn't know, on free slots
    if [[ ! -f "$state" ]]; then
        printf '%s\n' "-- Workspace blocks per monitor (conf/workspaces.lua). Slot N owns ids N*100+1..N*100+99" "return {" "}" >"$state"
    fi

    added=0
    # "<slot> <port>" of each monitor: its default workspace is slot*100+1
    while read -r slot name; do
        if grep -q "name = \"$name\"" "$state" || grep -q "slot = $slot," "$state"; then
            continue
        fi
        tmp="$(mktemp)"
        # Insert before the closing brace
        sed '$d' "$state" >"$tmp"
        printf '    { slot = %d, desc = "", name = "%s" },\n}\n' "$slot" "$name" >>"$tmp"
        cat "$tmp" >"$state"
        rm -f "$tmp"
        added=$((added + 1))
    done < <(sed -nE 's/.*workspace = "([0-9]+)", monitor = "([^"]+)", default = true.*/\1 \2/p' "$old" |
        awk '{ print int(($1 - 1) / 100), $2 }')

    rm -f "$old"
    echo "   Workspaces per monitor now live in Hyprland (conf/workspaces.lua); added $added monitor(s) from the old workspaces.lua"
fi
