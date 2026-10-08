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

# The theme for scheme $2 that goes with theme $1, like the shell's pairFor:
# itself, the pair it names, or the theme that names it (dark themes don't
# name their light version; the light ones name their dark one). Empty when
# there's none
_theme_pair_for() {
    local name="$1" scheme="$2"
    local file="$THEMES_DIR/$name.json"
    [[ -f "$file" ]] || return 0
    [[ "$(jq -r '.variant // "dark"' "$file")" == "$scheme" ]] && { echo "$name"; return 0; }
    local key back named
    [[ "$scheme" == "light" ]] && key="lightPair" back="darkPair" || key="darkPair" back="lightPair"
    named=$(jq -r --arg k "$key" '.[$k] // empty' "$file")
    [[ -n "$named" && -f "$THEMES_DIR/$named.json" ]] && { echo "$named"; return 0; }
    named=$(jq -r --arg s "$scheme" --arg b "$back" --arg n "$name" \
        'select((.variant // "dark") == $s and .[$b] == $n) | input_filename' "$THEMES_DIR"/*.json | head -n 1)
    [[ -n "$named" ]] && basename "$named" .json
    return 0
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
        lyne_state_set '.theme.mode = "preset" | .theme.name = $name' --arg name "$theme_name"
        echo "Theme set: $theme_name"
        ;;
    auto)
        lyne_state_set '.theme.mode = "auto"'
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
            # Switch to pair theme in preset mode, in the same write
            local pair_name=""
            local mode=$(_theme_get_mode)
            [[ "$mode" == "preset" ]] && pair_name=$(_theme_pair_for "$(_theme_get_name)" "$scheme_arg")
            lyne_state_set '.theme.scheme = $scheme | if $pair != "" then .theme.name = $pair else . end' \
                --arg scheme "$scheme_arg" --arg pair "$pair_name"

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
