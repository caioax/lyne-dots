#!/usr/bin/env bash
# XDG autostart entries for Settings › System › Autostart (AutostartService)
# and `lyne autostart`.
#
#   autostart.sh list         every entry, records "\x1e<scope>\t<path>\n<text>"
#                             (scope user/system), then the generated systemd
#                             units ("\x1eunits") and whether the session starts
#                             them ("\x1etarget": xdg-desktop-autostart.target)
#   autostart.sh hide <id>    turn <id>.desktop off from the next login
#   autostart.sh show <id>    turn it back on
#
# A user file (~/.config/autostart/<id>) replaces the system one with the same
# name. Turning a system entry off writes a small user file with Hidden=true
# and X-Lyne-Override=true, removed again to turn it on; a user entry just
# gets Hidden=true / Hidden=false.

set -u

USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
IFS=: read -r -a SYSTEM_DIRS <<<"${XDG_CONFIG_DIRS:-/etc/xdg}"

system_file() {
    local dir
    for dir in "${SYSTEM_DIRS[@]}"; do
        [[ -f "$dir/autostart/$1" ]] && { echo "$dir/autostart/$1"; return 0; }
    done
    return 1
}

# Sets Hidden=<value> in the [Desktop Entry] group of $1 (atomically)
set_hidden() {
    local file="$1" value="$2" tmp
    tmp="$(mktemp "$USER_DIR/.lyne-XXXXXX")" || return 1
    awk -v value="$value" '
        /^\[/ {
            if (entry && !done) { print "Hidden=" value; done = 1 }
            entry = ($0 == "[Desktop Entry]")
            print; next
        }
        entry && /^Hidden[ \t]*=/ { if (!done) { print "Hidden=" value; done = 1 }; next }
        { print }
        END { if (entry && !done) print "Hidden=" value }
    ' "$file" >"$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$file"
}

valid_id() {
    [[ "$1" == *.desktop && "$1" != */* && "$1" != .* ]]
}

case "${1:-}" in
list)
    shopt -s nullglob
    for f in "$USER_DIR"/*.desktop; do
        printf '\x1euser\t%s\n' "$f"
        cat "$f"
    done
    for dir in "${SYSTEM_DIRS[@]}"; do
        for f in "$dir"/autostart/*.desktop; do
            printf '\x1esystem\t%s\n' "$f"
            cat "$f"
        done
    done
    printf '\x1eunits\n'
    systemctl --user show 'app-*@autostart.service' -p Id,SourcePath,ActiveState,SubState,Result 2>/dev/null
    printf '\x1etarget\n'
    systemctl --user is-active xdg-desktop-autostart.target 2>/dev/null
    ;;
hide)
    id="${2:-}"
    valid_id "$id" || { echo "autostart.sh: bad id '$id'" >&2; exit 1; }
    mkdir -p "$USER_DIR"
    if [[ -f "$USER_DIR/$id" ]]; then
        set_hidden "$USER_DIR/$id" true
    elif sys="$(system_file "$id")"; then
        name="$(grep -m1 '^Name=' "$sys" | cut -d= -f2-)"
        tmp="$(mktemp "$USER_DIR/.lyne-XXXXXX")" || exit 1
        printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\nX-Lyne-Override=true\n' "${name:-$id}" >"$tmp"
        chmod 644 "$tmp" && mv -f "$tmp" "$USER_DIR/$id"
    else
        echo "autostart.sh: no entry '$id'" >&2
        exit 1
    fi
    ;;
show)
    id="${2:-}"
    valid_id "$id" || { echo "autostart.sh: bad id '$id'" >&2; exit 1; }
    file="$USER_DIR/$id"
    [[ -f "$file" ]] || exit 0
    if grep -q '^X-Lyne-Override=true' "$file"; then
        rm -f "$file"
    else
        set_hidden "$file" false
    fi
    ;;
*)
    echo "Usage: autostart.sh list | hide <id> | show <id>" >&2
    exit 1
    ;;
esac
