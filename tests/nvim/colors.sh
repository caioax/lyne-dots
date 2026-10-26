#!/usr/bin/env bash
# The color preview (nvim-colorizer.lua) in a headless Neovim with the
# repo's config: each file of fixtures/colors is opened and the colors it
# paints are read back (colors_probe.lua). QML reads 8 digits as
# #AARRGGBB and skips Qt.rgba() (0 to 1, not CSS's 0 to 255), CSS as
# #RRGGBBAA, Hyprland's rgba(RRGGBBAA) works in Lua, color names only count
# in CSS and QML, and <leader>uc turns the preview off and on.
#
# Usage: tests/nvim/colors.sh   (needs nvim and the plugins)
#   LYNE_TEST_NVIM=<dir>     another copy of nvim/.config/nvim (lib.sh)

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="$HERE/fixtures/colors"

need_tools nvim

nvim_sandbox
NVIM_PID=""

cleanup() {
    [[ -n "$NVIM_PID" ]] && kill "$NVIM_PID" 2>/dev/null
    remove_sandbox "$NVIM_PID"
}
trap cleanup EXIT

"$SB/nvim.sh" --headless "$FIXTURES/Sample.qml" >/dev/null 2>&1 &
NVIM_PID=$!
wait_for 15 test -S "$SB/nvim.sock" || fail_early "Neovim didn't start"

colors() { nv "luaeval('dofile(_A)', '$HERE/colors_probe.lua')"; }
painted() { [[ -n "$(colors)" ]]; }
# has COLOR: 1 when the buffer shows text=rrggbb
has() { grep -cxF "$1" <<<"$(colors)"; }
open() {
    nv "execute('edit $FIXTURES/$1')" >/dev/null
    wait_for 5 painted
}

wait_for 10 painted
check "QML: #80ff0000 is half red (alpha first), not green" 1 "$(has '#80ff0000=800000')"
check "QML: #ff7aa2f7 is the blue 7aa2f7" 1 "$(has '#ff7aa2f7=7aa2f7')"
check "QML: short hex" 1 "$(has '#f80=ff8800')"
check "QML: color names" 1 "$(has 'steelblue=4682b4')"
check "QML: Qt.rgba() isn't read as CSS's rgba()" 0 "$(colors | grep -c 'rgba')"

open sample.css
check "CSS: #ff000080 is half red (alpha last)" 1 "$(has '#ff000080=800000')"
check "CSS: rgb()" 1 "$(has 'rgb(80, 250, 123)=50fa7b')"
check "CSS: color names" 1 "$(has 'rebeccapurple=663399')"

open hypr.lua
check "Lua: Hyprland's rgba(RRGGBBAA)" 1 "$(has 'rgba(6F92E0ff)=6f92e0')"
check "Lua: hex" 1 "$(has '#7aa2f7=7aa2f7')"
check "Lua: a color name is just a word" 0 "$(colors | grep -c 'red=')"

open theme.json
check "JSON (themes): hex" 1 "$(has '#bd93f9=bd93f9')"

nvim --headless --server "$SB/nvim.sock" --remote-send ' uc' 2>/dev/null
sleep 0.5
check "<leader>uc turns the preview off" "" "$(colors)"
nvim --headless --server "$SB/nvim.sock" --remote-send ' uc' 2>/dev/null
wait_for 5 painted
check "<leader>uc again turns it back on" 1 "$(has '#bd93f9=bd93f9')"

exit "$failed"
