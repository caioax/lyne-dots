#!/usr/bin/env bash
# default-apps.sh - Default apps of Settings > System > Apps outside the shell
#
#   term <command> [args...]
#       Runs a command in the default terminal (apps with Terminal=true, the
#       launcher, lyne update...). Reads the terminal from state.json
#   apply <slot> <command> [desktop-id] [terminal 0|1]
#       Makes a default app the system default too:
#         terminal              Dolphin's "Open terminal here" (kdeglobals)
#         fileManager           folders opened by xdg-open
#         browser               links and web pages
#         editor                plain text files
#       Apps without a .desktop file, or that run in a terminal (nvim, yazi),
#       get a hidden lyne-<slot>.desktop that opens them through `term`
#   apply-all
#       apply for every slot with the values of state.json (install, migrations)
#   status <mime-type>...
#       Prints "<mime-type> <desktop file>" with what xdg-open uses now

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(dirname "$SELF")/../../../.."
STATE_FILE="$HOME/.config/quickshell/state.json"
DEFAULTS_FILE="$DOTS_DIR/.data/quickshell/defaults.json"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

# Kept in sync with AppsService.slots
declare -A MIMES=(
    [fileManager]="inode/directory"
    [browser]="x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml"
    [editor]="text/plain"
)

# How each terminal takes the command to run (the rest use -e). printf, as
# echo would take "-e" as its own flag
terminal_args() {
    case "$(basename "$1")" in
        foot) ;;
        wezterm) printf '%s\n' "start --" ;;
        gnome-terminal) printf '%s\n' "--" ;;
        xfce4-terminal | terminator) printf '%s\n' "-x" ;;
        *) printf '%s\n' "-e" ;;
    esac
}

# Value at a jq path of state.json, else of defaults.json
state_value() {
    local value=""
    [[ -f "$STATE_FILE" ]] && value="$(jq -r "$1 // empty" "$STATE_FILE" 2>/dev/null)"
    [[ -z "$value" && -f "$DEFAULTS_FILE" ]] && value="$(jq -r "$1 // empty" "$DEFAULTS_FILE" 2>/dev/null)"
    echo "$value"
}

# Path of the .desktop file with this id ("" when there's none)
desktop_file() {
    local id="$1" dir
    [[ -z "$id" ]] && return
    local dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"
    IFS=: read -ra list <<<"$dirs"
    for dir in "${list[@]}"; do
        if [[ -f "$dir/applications/$id.desktop" ]]; then
            echo "$dir/applications/$id.desktop"
            return
        fi
    done
}

cmd_term() {
    local terminal
    terminal="$(state_value '.apps.terminal.command')"
    terminal="${terminal:-kitty}"
    # The terminal command may carry its own flags ("wezterm --config x")
    read -ra argv <<<"$terminal"
    read -ra extra <<<"$(terminal_args "${argv[0]}")"
    exec "${argv[@]}" "${extra[@]}" "$@"
}

# Hidden .desktop file running `command` (in the terminal when asked), so
# xdg-open can hand it files
write_wrapper() {
    local slot="$1" command="$2" terminal="$3" mimes="$4"
    local exec="$command"
    [[ "$terminal" == 1 ]] && exec="$SELF term $command"
    local code="%F"
    [[ "$slot" == browser ]] && code="%U"

    mkdir -p "$APPS_DIR"
    cat >"$APPS_DIR/lyne-$slot.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$command (lyne $slot)
Comment=Default $slot chosen in Settings > System > Apps
Exec=$exec $code
Terminal=false
NoDisplay=true
MimeType=${mimes// /;};
EOF
}

cmd_apply() {
    local slot="$1" command="${2:-}" id="${3:-}" terminal="${4:-}"
    [[ -z "$command" ]] && return 0

    # No id: the command's own .desktop file, if it has one
    [[ -z "$id" ]] && id="$(basename "${command%% *}")"
    local file
    file="$(desktop_file "$id")"
    if [[ -z "$terminal" ]]; then
        terminal=0
        [[ -n "$file" ]] && grep -qi '^Terminal=true' "$file" && terminal=1
    fi

    if [[ "$slot" == terminal ]]; then
        command -v kwriteconfig6 >/dev/null || return 0
        local service=""
        [[ -n "$file" ]] && service="$id.desktop"
        # kdeglobals is a stowed file: only write when it changes
        if [[ "$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication)" != "$command" ]]; then
            kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "$command"
        fi
        if [[ "$(kreadconfig6 --file kdeglobals --group General --key TerminalService)" != "$service" ]]; then
            kwriteconfig6 --file kdeglobals --group General --key TerminalService "$service"
        fi
        return 0
    fi

    local mimes="${MIMES[$slot]:-}"
    [[ -z "$mimes" ]] && return 0
    local target="$id.desktop"
    if [[ -z "$file" || "$terminal" == 1 ]]; then
        write_wrapper "$slot" "$command" "$terminal" "$mimes"
        target="lyne-$slot.desktop"
    else
        rm -f "$APPS_DIR/lyne-$slot.desktop"
    fi
    # shellcheck disable=SC2086
    xdg-mime default "$target" $mimes
}

cmd_apply_all() {
    local slot
    for slot in terminal fileManager browser; do
        cmd_apply "$slot" "$(state_value ".apps.$slot.command")" "$(state_value ".apps.$slot.desktop")"
    done
    cmd_apply editor "$(state_value '.system.editor')"
}

cmd_status() {
    local mime
    for mime in "$@"; do
        echo "$mime $(xdg-mime query default "$mime" 2>/dev/null)"
    done
}

case "${1:-}" in
    term)
        shift
        cmd_term "$@"
        ;;
    apply)
        shift
        cmd_apply "$@"
        ;;
    apply-all) cmd_apply_all ;;
    status)
        shift
        cmd_status "$@"
        ;;
    *)
        echo "usage: $(basename "$0") term <command...> | apply <slot> <command> [desktop-id] [0|1] | apply-all | status <mime...>" >&2
        exit 1
        ;;
esac
