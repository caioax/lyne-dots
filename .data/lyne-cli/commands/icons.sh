# lyne icons - The icon theme

local subcmd="${1:-status}"
local defaults_file="$DOTS_DIR/.data/quickshell/defaults.json"

source "$DOTS_DIR/.data/lyne-cli/lib/icons.sh"

# The saved family: state.json, else defaults.json, else the lib's default
_icons_saved() {
    local value=""
    value="$(jq -r '.icons.theme // empty' "$(lyne_state_file)" 2>/dev/null)"
    [[ -n "$value" ]] || value="$(jq -r '.icons.theme // empty' "$defaults_file" 2>/dev/null)"
    printf '%s\n' "${value:-$ICONS_DEFAULT_THEME}"
}

# Applies the saved family's variant for MODE (default: GSettings' mode);
# running Qt apps are told once they've read qt6ct's file again
# (LYNE_ICONS_NOTIFY_DELAY seconds later, 4 by default)
_icons_apply_saved() {
    local mode="${1:-$(icons_mode)}" variant
    variant="$(icons_variant "$(_icons_saved)" "$mode")" || {
        echo "No icon theme named '$(_icons_saved)' (see lyne icons list)" >&2
        return 1
    }
    local out
    out="$(icons_apply "$variant")" || return 1
    if [[ "$out" == reload ]]; then
        (sleep "${LYNE_ICONS_NOTIFY_DELAY:-4}" && icons_notify) >/dev/null 2>&1 &
        disown
    fi
    printf '%s\n' "$variant"
}

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne icons [status|list|--json|set <theme>|apply [dark|light]]"
        echo ""
        echo "The icon theme, also in Settings > Icons. Themes are the folders with an"
        echo "index.theme listing icons in ~/.local/share/icons, ~/.icons and"
        echo "/usr/share/icons. A theme with -dark and -light versions (Tela-blue,"
        echo "Papirus...) is one theme here: the version that fits the shell's theme"
        echo "(dark or light) is used, and changes with it."
        echo ""
        echo "Subcommands:"
        echo "  status               The theme in use and the installed ones (default)"
        echo "  list                 Installed themes: id, name, folder, dark and light versions"
        echo "  --json               The installed themes as JSON"
        echo "  set <theme>          Use a theme (by id, as in list)"
        echo "  apply [dark|light]   Apply the saved theme again (for the current mode)"
        ;;
    status)
        local current mode id name dir dark light _ any=false
        current="$(_icons_saved)"
        mode="$(icons_mode)"
        if icons_family "$current" >/dev/null; then
            echo "Theme: $current ($mode mode: $(icons_variant "$current" "$mode"))"
        else
            echo "Theme: $current"
            echo "  (not installed: apps fall back to another theme)"
        fi
        echo ""
        while IFS=$'\x1f' read -r id name dir dark light _; do
            any=true
            printf '  %s %-24s %s%s\n' "$([[ "$id" == "$current" ]] && echo "●" || echo "○")" "$id" \
                "${dir/#$HOME/\~}" "$([[ -n "$dark$light" ]] && echo " (dark and light)")"
        done < <(_icons_split)
        [[ $any == true ]] || echo "No icon themes found"
        ;;
    list)
        local id name dir dark light _
        while IFS=$'\x1f' read -r id name dir dark light _; do
            printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$name" "${dir/#$HOME/\~}" "$dark" "$light"
        done < <(_icons_split)
        ;;
    --json)
        icons_json
        ;;
    set)
        [[ -n "${2:-}" ]] || { echo "Usage: lyne icons set <theme>"; return 1; }
        local family
        family="$(icons_family "$2")" || {
            echo "No icon theme named '$2' (see lyne icons list)" >&2
            return 1
        }
        lyne_state_set '.icons.theme = $t' --arg t "$family" ||
            echo "Couldn't save it to $(lyne_state_file)" >&2
        # Applied here too, for when the shell isn't running
        local variant
        variant="$(_icons_apply_saved)" || return 1
        echo "Icons: $family ($variant)"
        ;;
    apply)
        case "${2:-}" in
            ""|dark|light) _icons_apply_saved "${2:-}" >/dev/null ;;
            *) echo "Usage: lyne icons apply [dark|light]"; return 1 ;;
        esac
        ;;
    *)
        echo "Unknown subcommand: $subcmd"
        echo "Run 'lyne icons --help' for usage."
        return 1
        ;;
esac
