# 028-launcher-on-super.sh - The launcher opens by tapping Super; Super + Space
# switches keyboard layouts
#
# conf/keybinds.lua moved the app launcher from SUPER + Space to Super alone
# (bound on release, so Super + anything else still works) and gave
# SUPER + Space to the new "Next keyboard layout" bind. Someone who already
# uses SUPER + Space for a custom shortcut, or moved another bind there in
# Settings › Keybinds, keeps it: the new bind is left without keys (they can
# pick others in Settings).

local state="$HOME/.config/quickshell/state.json"

_028_run() {
    [[ -f "$state" ]] && command -v jq &>/dev/null || return 0

    local taken
    taken="$(jq -r '
        def combo: ascii_upcase | gsub("\\s"; "") | gsub("^(MOD4|WIN|META)\\+"; "SUPER+");
        [((.keybinds.custom // [])[] | select((.keys // "") | combo == "SUPER+SPACE") | (.description // .command)),
         ((.keybinds.overrides // [])[] | select(.id != "switch-layout" and ((.keys // "") | combo == "SUPER+SPACE")) | .id)]
        | join(", ")' "$state")"

    if [[ -n "$taken" ]] && ! jq -e '(.keybinds.overrides // []) | any(.id == "switch-layout")' "$state" &>/dev/null; then
        local tmp
        tmp="$(mktemp)"
        if jq '.keybinds = ((.keybinds // {}) + { overrides: ((.keybinds.overrides // []) + [{ id: "switch-layout", keys: "" }]) })' "$state" >"$tmp"; then
            cat "$tmp" >"$state"
            echo "   SUPER + Space stays with $taken; \"Next keyboard layout\" has no keys (Settings › Hyprland › Keybinds)"
        fi
        rm -f "$tmp"
    fi
    echo "   The app launcher now opens by tapping Super (change it in Settings › Hyprland › Keybinds)"
}

_028_run
unset -f _028_run
