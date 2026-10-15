#!/usr/bin/env bash
# Power profiles daemon for PowerProfileService (Settings › System › Power
# profiles), from lyne's power-profiles.sh lib.
#
#   power-profiles.sh state     ok|stopped <daemon>, missing <candidate> or
#                               conflict <blocker> (see the lib)
#   power-profiles.sh install   install and enable the daemon (sudo)

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.data/lyne-cli/lib/power-profiles.sh"

case "${1:-}" in
    state) pp_state ;;
    install) pp_install ;;
    *)
        echo "Usage: power-profiles.sh state|install" >&2
        exit 1
        ;;
esac
