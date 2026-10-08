# lyne state - Manage state.json

local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local DEFAULTS_FILE="$DOTS_DIR/.data/quickshell/defaults.json"
local subcmd="${1:-}"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne state [subcommand]"
        echo ""
        echo "Manage the QuickShell state.json configuration file."
        echo ""
        echo "Subcommands:"
        echo "  (none)    Open state.json in your configured editor"
        echo "  sync      Merge with defaults.json (preserves your values)"
        echo "  rebuild   Replace with a fresh copy from defaults.json"
        ;;
    sync)
        echo ":: Syncing state.json with defaults..."
        source "$DOTS_DIR/.data/lyne-cli/lib/sync-state.sh"
        ;;
    rebuild)
        if [[ ! -f "$DEFAULTS_FILE" ]]; then
            echo "lyne state: defaults.json not found at $DEFAULTS_FILE"
            return 1
        fi

        echo -n "This will replace state.json with defaults. Continue? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "lyne state: cancelled"
            return 0
        fi

        lyne_state_replace <"$DEFAULTS_FILE"
        echo "lyne state: rebuilt state.json from defaults"
        ;;
    "")
        local default_editor="nvim"
        local custom_editor
        custom_editor=$(jq -r '.system.editor // empty' "$STATE_FILE" 2>/dev/null)

        if [[ -n "$custom_editor" && "$custom_editor" != "null" ]] && command -v "${custom_editor%% *}" >/dev/null 2>&1; then
            eval "$custom_editor $STATE_FILE"
        else
            [[ -n "$custom_editor" && "$custom_editor" != "null" ]] && \
                echo "lyne state: editor '$custom_editor' not found, falling back to $default_editor"
            $default_editor "$STATE_FILE"
        fi
        ;;
    *)
        echo "lyne state: unknown subcommand '$subcmd'"
        echo "Run 'lyne state --help' for usage information."
        ;;
esac
