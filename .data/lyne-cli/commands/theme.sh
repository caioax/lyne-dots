# lyne theme - Manage theme settings

local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local THEMES_DIR="$HOME/.local/themes"
local subcmd="${1:-}"

_theme_get_mode() {
    jq -r '.theme.mode // "preset"' "$STATE_FILE" 2>/dev/null
}

_theme_get_name() {
    jq -r '.theme.name // "tokyonight"' "$STATE_FILE" 2>/dev/null
}

_theme_get_scheme() {
    jq -r '.theme.scheme // "dark"' "$STATE_FILE" 2>/dev/null
}

_theme_set_state() {
    local key="$1" value="$2"
    local tmp
    tmp=$(mktemp)
    jq --arg v "$value" ".$key = \$v" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne theme [subcommand]"
        echo ""
        echo "Manage the theme mode and active preset."
        echo ""
        echo "Subcommands:"
        echo "  (none)    Show current theme info"
        echo "  list      List available theme presets"
        echo "  set NAME  Switch to preset mode with the given theme"
        echo "  auto      Switch to auto (Material You) mode"
        echo "  mode      Show current mode (preset or auto)"
        echo "  scheme    Show or set color scheme (dark or light)"
        ;;
    list)
        echo "Available themes:"
        for f in "$THEMES_DIR"/*.json; do
            [[ -f "$f" ]] || continue
            local name
            name=$(basename "$f" .json)
            local display
            display=$(jq -r '.name // empty' "$f" 2>/dev/null)
            if [[ -n "$display" ]]; then
                echo "  $name ($display)"
            else
                echo "  $name"
            fi
        done
        ;;
    set)
        local theme_name="${2:-}"
        if [[ -z "$theme_name" ]]; then
            echo "Usage: lyne theme set <name>"
            echo "Run 'lyne theme list' to see available themes."
            return 1
        fi
        if [[ ! -f "$THEMES_DIR/$theme_name.json" ]]; then
            echo "lyne theme: unknown theme '$theme_name'"
            echo "Run 'lyne theme list' to see available themes."
            return 1
        fi
        _theme_set_state "theme.mode" "preset"
        _theme_set_state "theme.name" "$theme_name"
        echo "Theme set: $theme_name"
        ;;
    auto)
        _theme_set_state "theme.mode" "auto"
        echo "Switched to auto (Material You) mode."
        ;;
    mode)
        _theme_get_mode
        ;;
    scheme)
        local scheme_arg="${2:-}"
        if [[ -z "$scheme_arg" ]]; then
            _theme_get_scheme
        elif [[ "$scheme_arg" == "dark" || "$scheme_arg" == "light" ]]; then
            _theme_set_state "theme.scheme" "$scheme_arg"

            # Switch to pair theme in preset mode
            local mode=$(_theme_get_mode)
            if [[ "$mode" == "preset" ]]; then
                local current_name=$(_theme_get_name)
                local theme_file="$THEMES_DIR/$current_name.json"
                if [[ -f "$theme_file" ]]; then
                    local pair_key
                    [[ "$scheme_arg" == "light" ]] && pair_key="lightPair" || pair_key="darkPair"
                    local pair_name
                    pair_name=$(jq -r ".$pair_key // empty" "$theme_file" 2>/dev/null)
                    if [[ -n "$pair_name" && -f "$THEMES_DIR/$pair_name.json" ]]; then
                        _theme_set_state "theme.name" "$pair_name"
                    fi
                fi
            fi

            echo "Color scheme set to: $scheme_arg"
        else
            echo "lyne theme scheme: must be 'dark' or 'light'"
            return 1
        fi
        ;;
    "")
        local mode name scheme
        mode=$(_theme_get_mode)
        name=$(_theme_get_name)
        scheme=$(_theme_get_scheme)
        echo "Theme mode:   $mode"
        echo "Color scheme: $scheme"
        if [[ "$mode" == "preset" ]]; then
            echo "Active preset: $name"
        else
            echo "Colors generated from current wallpaper"
        fi
        ;;
    *)
        echo "lyne theme: unknown subcommand '$subcmd'"
        echo "Run 'lyne theme --help' for usage information."
        ;;
esac
