# 018-special-workspaces-ids.sh - Follow the renamed music special workspace
#
# Special workspaces are now a list in Settings › Hyprland › Specials, and
# the Spotify one became "music" (any player can open there). Keys changed
# in Settings › Keybinds for its binds move to the new bind ids.

state="$HOME/.config/quickshell/state.json"

if [[ -f "$state" ]] && command -v jq &>/dev/null; then
    tmp="$(mktemp)"
    if jq '
        if (.keybinds.overrides | type) == "array" then
            .keybinds.overrides |= map(
                if .id == "special-spotify" then .id = "special-music"
                elif .id == "move-to-spotify" then .id = "move-to-music"
                else . end)
        else . end' "$state" >"$tmp"; then
        cat "$tmp" >"$state"
        echo "   Moved Spotify keybind changes to the music special workspace"
    fi
    rm -f "$tmp"
fi
