#!/usr/bin/env bash
# Zen Browser theme for ZenService (Settings › Theme › Zen Browser), from
# lyne's zen.sh lib (.data/lyne-cli/lib/zen.sh).
#
#   zen.sh json            the profiles as JSON
#   zen.sh palette         ~/.cache/lyne/zen.json from stdin (atomically),
#                          then the CSS of every enabled profile
#   zen.sh apply           the CSS of every enabled profile
#   zen.sh enable <dir>    add the theme to a profile
#   zen.sh disable <dir>   remove it
#
# Options come in LYNE_ZEN_OPTIONS (state.json is saved a moment later).

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/zen.sh"

case "${1:-}" in
    json) zen_json ;;
    palette)
        mkdir -p "$(dirname "$ZEN_PALETTE")" &&
            _zen_write "$ZEN_PALETTE" &&
            zen_apply
        ;;
    apply) zen_apply ;;
    enable) zen_enable "${2:?profile dir}" ;;
    disable) zen_disable "${2:?profile dir}" ;;
    *)
        echo "Usage: zen.sh json|palette|apply|enable <dir>|disable <dir>" >&2
        exit 1
        ;;
esac
