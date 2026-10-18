#!/usr/bin/env bash
# Mouse cursor themes for CursorService (Settings › Cursor), from lyne's
# cursor.sh lib.
#
#   cursor.sh json                 the installed themes as JSON
#   cursor.sh apply <theme> <size> switch Hyprland, GTK and the default theme

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/cursor.sh"

case "${1:-}" in
    json) cursor_json ;;
    apply) cursor_apply "${2:-}" "${3:-}" ;;
    *)
        echo "Usage: cursor.sh json|apply <theme> <size>" >&2
        exit 1
        ;;
esac
