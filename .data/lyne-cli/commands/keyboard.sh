# lyne keyboard - Show the keyboard layouts in use

local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local DEFAULTS_FILE="$DOTS_DIR/.data/quickshell/defaults.json"
local LEGACY_FILE="$HOME/.config/hypr/local/extra_input.lua"
local subcmd="${1:-status}"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne keyboard [status]"
        echo ""
        echo "Keyboard layouts, key options and keyboards with their own layouts."
        echo "Change them in Settings › Hyprland › Keyboard."
        echo ""
        echo "Subcommands:"
        echo "  status    Saved settings and what each connected keyboard types with (default)"
        ;;
    status)
        if ! command -v jq &>/dev/null; then
            echo "lyne keyboard: jq is required"
            return 1
        fi

        echo "Every keyboard (Settings › Hyprland › Keyboard)"
        jq -r --slurpfile d "$DEFAULTS_FILE" '
            ($d[0].hyprland.input // {}) + (.hyprland.input // {}) as $i
            | "  layouts   \($i.kb_layout // "us")" + (if ($i.kb_variant // "") != "" then "  (variants \($i.kb_variant))" else "" end),
              "  options   \(if ($i.kb_options // "") == "" then "none" else $i.kb_options end)",
              "  model     \(if ($i.kb_model // "") == "" then "default" else $i.kb_model end)",
              "  num lock  \(if $i.numlock_by_default == true then "on at login" else "off" end)",
              "  repeat    \($i.repeat_delay // 250) ms, \($i.repeat_rate // 25)/s"' "$STATE_FILE"

        echo ""
        echo "Keyboards with their own layouts"
        jq -r '
            (.keyboard.devices // []) as $d
            | if ($d | length) == 0 then "  none"
              else $d[] | "  \(.name)  \(.layout // "same layouts")"
                + (if (.variant // "") != "" then " (\(.variant))" else "" end)
                + (if .options != null then "  options \(.options)" else "" end)
                + (if .model != null then "  model \(.model)" else "" end)
              end' "$STATE_FILE"

        if hyprctl version &>/dev/null; then
            echo ""
            echo "Typing now (hyprctl devices)"
            hyprctl devices -j | jq -r '
                .keyboards[]
                | select(.name | test("power-button|sleep-button|lid-switch|video-bus|consumer-control|system-control|radio-control|wmi|hotkeys|avrcp|intel-hid|virtual") | not)
                | "  \(if .main then "*" else " " end) \(.name)  \(.active_keymap)  [\(.layout)\(if .variant != "" then " / " + .variant else "" end)]"'
        fi

        if [[ -f "$LEGACY_FILE" ]]; then
            echo ""
            echo "hypr/local/extra_input.lua is still loaded (written by hand): import it in"
            echo "Settings › Hyprland › Keyboard"
        fi
        ;;
    *)
        echo "lyne keyboard: unknown subcommand '$subcmd'"
        echo "Run 'lyne keyboard --help' for usage information."
        return 1
        ;;
esac
