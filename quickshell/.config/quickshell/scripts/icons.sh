#!/usr/bin/env bash
# Icon themes for IconService (Settings › Icons), from lyne's icons.sh lib.
#
#   icons.sh json            the installed themes (families) as JSON
#   icons.sh apply <theme>   use that theme (a variant) in GTK, Qt and KDE
#   icons.sh notify          tell running KDE/Qt apps to load the icons again

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/icons.sh"

case "${1:-}" in
    json) icons_json ;;
    apply) icons_apply "${2:-}" ;;
    notify) icons_notify ;;
    *)
        echo "Usage: icons.sh json|apply <theme>|notify" >&2
        exit 1
        ;;
esac
