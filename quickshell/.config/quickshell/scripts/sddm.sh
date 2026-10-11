#!/usr/bin/env bash
# Login screen sync for SddmService (Settings › Theme › Login screen), from
# lyne's sddm.sh lib (.data/lyne-cli/lib/sddm.sh).
#
#   sddm.sh state       ok, absent, missing or foreign <owner> (see the lib)
#   sddm.sh apply       copy the palette, wallpaper and avatar (or reset
#                       to the theme's defaults with the sync off)
#
# Options come in LYNE_SDDM_OPTIONS (state.json is saved a moment later).

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/sddm.sh"

case "${1:-}" in
    state) sddm_state ;;
    apply) sddm_apply ;;
    *)
        echo "Usage: sddm.sh state|apply" >&2
        exit 1
        ;;
esac
