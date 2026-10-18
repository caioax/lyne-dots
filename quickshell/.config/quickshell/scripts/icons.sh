#!/usr/bin/env bash
# Icon themes for IconService (Settings › Icons), from lyne's icons.sh lib.
#
#   icons.sh json            the installed themes (families) as JSON
#   icons.sh apply <theme>   use that theme (a variant) in GTK, Qt and KDE
#   icons.sh notify          tell running KDE/Qt apps to load the icons again
#   icons.sh install <file>  install the themes inside (see the lib's
#                            icons_install for the output and codes)
#   icons.sh remove <id>     delete one of the user's themes (a family)
#   icons.sh preview <id>... the files of a few icons per theme, as JSON
#                            (icon-preview.py, over the lib's icon dirs)

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/icons.sh"

case "${1:-}" in
    json) icons_json ;;
    apply) icons_apply "${2:-}" ;;
    notify) icons_notify ;;
    install) icons_install "${2:-}" ;;
    remove) icons_remove "${2:-}" ;;
    preview)
        shift
        python3 "$(dirname "$SELF")/icon-preview.py" "$(cursor_dirs | paste -sd:)" "$@"
        ;;
    *)
        echo "Usage: icons.sh json|apply <theme>|notify|install <archive>|remove <theme>|preview <theme>..." >&2
        exit 1
        ;;
esac
