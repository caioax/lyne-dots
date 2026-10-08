# 032-wallpaper-picker-key.sh - SUPER + B opens the wallpaper picker
#
# conf/keybinds.lua gave the "Wallpapers" bind, which had no keys, SUPER + B.
# Someone who already uses SUPER + B for a custom shortcut, a special
# workspace, or moved another bind there in Settings › Keybinds, keeps it:
# the wallpaper bind is left without keys (they can pick others in Settings).

local state="$HOME/.config/quickshell/state.json"

_032_run() {
    [[ -f "$state" ]] && command -v jq &>/dev/null || return 0
    # Keys already picked in Settings stay
    jq -e '(.keybinds.overrides // []) | any(.id == "wallpapers")' "$state" &>/dev/null && return 0

    local taken
    taken="$(jq -r '
        def combo: ascii_upcase | gsub("\\s"; "") | gsub("^(MOD4|WIN|META)\\+"; "SUPER+");
        [((.keybinds.custom // [])[] | select((.keys // "") | combo == "SUPER+B") | (.description // .command)),
         ((.keybinds.overrides // [])[] | select(.id != "wallpapers" and ((.keys // "") | combo == "SUPER+B")) | .id),
         ((.specials.list // [])[] | select(((.keys // "") | combo == "SUPER+B") or ((.moveKeys // "") | combo == "SUPER+B")) | .name)]
        | join(", ")' "$state")"

    if [[ -n "$taken" ]]; then
        local tmp
        tmp="$(mktemp)"
        if jq '.keybinds = ((.keybinds // {}) + { overrides: ((.keybinds.overrides // []) + [{ id: "wallpapers", keys: "" }]) })' "$state" >"$tmp"; then
            lyne_state_replace <"$tmp"
            echo "   SUPER + B stays with $taken; \"Wallpaper picker\" has no keys (Settings › Hyprland › Keybinds)"
        fi
        rm -f "$tmp"
        return 0
    fi
    echo "   SUPER + B opens the wallpaper picker (change it in Settings › Hyprland › Keybinds)"
}

_032_run
unset -f _032_run
