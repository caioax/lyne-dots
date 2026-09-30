# lyne autostart - Show what starts at login

local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local SYSTEM_FILE="${XDG_RUNTIME_DIR:-/tmp}/lyne-autostart.json"
local LEGACY_FILE="$HOME/.config/hypr/local/autostart.lua"
local USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
local subcmd="${1:-status}"
local tilde="~"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne autostart [status]"
        echo ""
        echo "Programs started at login. Add, change or switch them off in"
        echo "Settings › System › Autostart."
        echo ""
        echo "Subcommands:"
        echo "  status    System programs, your apps, special workspaces and XDG"
        echo "            autostart entries, with their state (default)"
        ;;
    status)
        if ! command -v jq &>/dev/null; then
            echo "lyne autostart: jq is required"
            return 1
        fi

        echo "System (always started, hypr/conf/autostart.lua)"
        if [[ -f "$SYSTEM_FILE" ]]; then
            jq -r '.system[] | "  \(.name | .[0:22] | . + " " * (22 - length))  \(.command)"' "$SYSTEM_FILE" |
                sed "s|$HOME/|~/|g"
        else
            echo "  (Hyprland didn't export the list: is conf/autostart.lua loaded? hyprctl configerrors)"
        fi

        echo ""
        echo "Your apps (Settings › System › Autostart)"
        jq -r '
            (.autostart.apps // []) as $apps
            | if ($apps | length) == 0 then "  none"
              else $apps[] | "  \(if .enabled == false then "off" else "on " end)  \(.name | .[0:22] | . + " " * (22 - length))  \(.command)"
                + (if (.delay // 0) > 0 then "  (after \(.delay) s)" else "" end)
                + (if (.workspace // "") != "" then "  (on \(.workspace))" else "" end)
              end' "$STATE_FILE" | sed "s|$HOME/|~/|g"

        echo ""
        echo "Special workspaces opened at login (Settings › Hyprland › Specials)"
        jq -r '
            [(.specials.list // [])[] | select(.autostart == true and (.command // "") != "")] as $s
            | if ($s | length) == 0 then "  none"
              else $s[] | "  \(.name | .[0:22] | . + " " * (22 - length))  \(.command)  (hidden in special:\(.id))" end' "$STATE_FILE"

        echo ""
        if [[ "$(systemctl --user is-active xdg-desktop-autostart.target 2>/dev/null)" == "active" ]]; then
            echo "XDG autostart (started by systemd)"
        else
            echo "XDG autostart (NOT started in this session: log in with Hyprland (uwsm))"
        fi
        local units
        units="$(systemctl --user show 'app-*@autostart.service' -p SourcePath,ActiveState,Result 2>/dev/null)"
        local shown=0 source active result state
        # One "source<TAB>active<TAB>result" line per generated unit
        while IFS=$'\t' read -r source active result; do
            [[ -z "$source" ]] && continue
            case "$active/$result" in
                active/* | activating/*) state="running" ;;
                */exec-condition) continue ;;
                failed/*) state="failed " ;;
                inactive/success) state="ran    " ;;
                *) state="$active" ;;
            esac
            printf '  %s  %s\n' "$state" "${source/#$HOME\//$tilde/}"
            shown=$((shown + 1))
        done < <(awk -F= '
            /^SourcePath=/ { src = substr($0, 12) }
            /^ActiveState=/ { act = $2 }
            /^Result=/ { res = $2 }
            /^$/ { if (src != "") print src "\t" act "\t" res; src = act = res = "" }
            END { if (src != "") print src "\t" act "\t" res }' <<<"$units")
        local f
        for f in "$USER_DIR"/*.desktop; do
            [[ -f "$f" ]] || continue
            if awk '/^\[/{e=($0=="[Desktop Entry]")} e && /^Hidden[ \t]*=[ \t]*true/{found=1} END{exit !found}' "$f"; then
                printf '  off      %s\n' "${f/#$HOME\//$tilde/}"
                shown=$((shown + 1))
            fi
        done
        [[ $shown -eq 0 ]] && echo "  none for this desktop"

        if [[ -f "$LEGACY_FILE" ]]; then
            echo ""
            echo "hypr/local/autostart.lua is still loaded (written by hand): import it in"
            echo "Settings › System › Autostart"
        fi
        ;;
    *)
        echo "lyne autostart: unknown subcommand '$subcmd'"
        echo "Run 'lyne autostart --help' for usage information."
        return 1
        ;;
esac
