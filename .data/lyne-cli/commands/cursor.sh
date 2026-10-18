# lyne cursor - The mouse cursor theme and size

local subcmd="${1:-status}"
local defaults_file="$DOTS_DIR/.data/quickshell/defaults.json"

source "$DOTS_DIR/.data/lyne-cli/lib/cursor.sh"

# cursor.<key> from state.json, else defaults.json, else the lib's default
_cursor_setting() {
    local value=""
    value="$(jq -r --arg k "$1" '.cursor[$k] // empty' "$(lyne_state_file)" 2>/dev/null)"
    [[ -n "$value" ]] || value="$(jq -r --arg k "$1" '.cursor[$k] // empty' "$defaults_file" 2>/dev/null)"
    [[ -n "$value" ]] || value="$2"
    printf '%s\n' "$value"
}

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne cursor [status|list|--json|set <theme> [size]|size <size>|apply]"
        echo ""
        echo "The mouse cursor theme, also in Settings > Cursor. Themes are the folders"
        echo "with xcursor files (cursors/) in ~/.local/share/icons, ~/.icons and"
        echo "/usr/share/icons. Hyprland and apps that let it draw their cursor change"
        echo "at once; other apps (X11 ones, for instance) when you reopen them."
        echo ""
        echo "Subcommands:"
        echo "  status               The theme and size in use, and the themes (default)"
        echo "  list                 Installed themes: id, name and folder"
        echo "  --json               The installed themes as JSON"
        echo "  set <theme> [size]   Use a theme (by id, as in list), and a size"
        echo "  size <size>          Change only the size (24, 32, 48 or 64 look sharpest)"
        echo "  apply                Apply the saved theme and size again"
        ;;
    status)
        local current size id name dir hypr any=false
        current="$(_cursor_setting theme "$CURSOR_DEFAULT_THEME")"
        size="$(_cursor_setting size "$CURSOR_DEFAULT_SIZE")"
        echo "Theme: $current, size $size"
        cursor_has "$current" || echo "  (not installed: apps fall back to another theme)"
        echo ""
        while IFS=$'\t' read -r id name dir hypr; do
            any=true
            printf '  %s %-30s %s%s\n' "$([[ "$id" == "$current" ]] && echo "●" || echo "○")" "$id" \
                "${dir/#$HOME/\~}" "$([[ $hypr == 1 ]] && echo " (hyprcursor too)")"
        done < <(cursor_themes)
        [[ $any == true ]] || echo "No cursor themes found"
        ;;
    list)
        local id name dir hypr
        while IFS=$'\t' read -r id name dir hypr; do
            printf '%s\t%s\t%s\n' "$id" "$name" "${dir/#$HOME/\~}"
        done < <(cursor_themes)
        ;;
    --json)
        cursor_json
        ;;
    set|size)
        local theme size
        if [[ "$subcmd" == set ]]; then
            [[ -n "${2:-}" ]] || { echo "Usage: lyne cursor set <theme> [size]"; return 1; }
            theme="$2"
            size="${3:-$(_cursor_setting size "$CURSOR_DEFAULT_SIZE")}"
        else
            [[ -n "${2:-}" ]] || { echo "Usage: lyne cursor size <size>"; return 1; }
            theme="$(_cursor_setting theme "$CURSOR_DEFAULT_THEME")"
            size="$2"
        fi
        # Applied here too, for when the shell isn't running; the shell
        # applies the saved values again and writes them for Hyprland
        cursor_apply "$theme" "$size" || return 1
        lyne_state_set '.cursor.theme = $t | .cursor.size = ($s | tonumber)' --arg t "$theme" --arg s "$size" ||
            echo "Couldn't save it to $(lyne_state_file)" >&2
        echo "Cursor: $theme, size $size"
        ;;
    apply)
        cursor_apply "$(_cursor_setting theme "$CURSOR_DEFAULT_THEME")" "$(_cursor_setting size "$CURSOR_DEFAULT_SIZE")"
        ;;
    *)
        echo "Unknown subcommand: $subcmd"
        echo "Run 'lyne cursor --help' for usage."
        return 1
        ;;
esac
