#!/usr/bin/env bash
# Mouse cursor themes for CursorService (Settings › Cursor), from lyne's
# cursor.sh lib.
#
#   cursor.sh json                 the installed themes as JSON
#   cursor.sh apply <theme> <size> switch Hyprland, GTK and the default theme
#   cursor.sh install <archive>    install the themes inside (see the lib's
#                                  cursor_install for the output and codes)
#   cursor.sh remove <theme>       delete one of the user's themes

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/cursor.sh"

case "${1:-}" in
    json) cursor_json ;;
    apply) cursor_apply "${2:-}" "${3:-}" ;;
    install) cursor_install "${2:-}" ;;
    remove) cursor_remove "${2:-}" ;;
    *)
        echo "Usage: cursor.sh json|apply <theme> <size>|install <archive>|remove <theme>" >&2
        exit 1
        ;;
esac
