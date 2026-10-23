#!/usr/bin/env bash
# The shortcut search (nvim/.config/nvim/lua/config/shortcuts.lua):
# - its pieces in a headless Neovim: tmux's `list-keys -N` parser on a
#   fixture, and Neovim's maps (modes merged, the LSP and git keys of
#   config/buffer_keys.lua listed in any buffer, where each map was made)
# - the guides (prefix + N / T): every key they cite exists in the config
# - for real: prefix + ? in a tmux server of its own (like nav.sh) opens the
#   popup, whose Neovim runs in the sandbox (the server's environment points
#   its XDG folders there) and is reached through its socket: the list has
#   both sides, typing filters it, Escape closes the list and the popup.
#
# Usage: tests/nvim/shortcuts.sh   (needs tmux, nvim, python3 and the plugins)
#   LYNE_TEST_NVIM=<dir>       another copy of nvim/.config/nvim (lib.sh)
#   LYNE_TEST_TMUX_CONF=<file> another copy of tmux/.tmux.conf
#   LYNE_TEST_TMUX_GUIDE=<file> another copy of tmux/README.md

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_CONF="${LYNE_TEST_TMUX_CONF:-$REPO/tmux/.tmux.conf}"
TMUX_GUIDE="${LYNE_TEST_TMUX_GUIDE:-$REPO/tmux/README.md}"

need_tools tmux nvim python3

nvim_sandbox
SOCK="$SB/tmux.sock"
NVIM_PID=""
CLIENT_PID=""

T() { tmux -S "$SOCK" "$@"; }

cleanup() {
    local popup_pid
    popup_pid="$(pgrep -f "lua require\(\[\[config.shortcuts\]\]\)" -P "$(T display -p '#{pid}' 2>/dev/null || echo 0)" 2>/dev/null | head -1)"
    [[ -n "$NVIM_PID" ]] && kill "$NVIM_PID" 2>/dev/null
    [[ -n "$CLIENT_PID" ]] && kill "$CLIENT_PID" 2>/dev/null
    T kill-server 2>/dev/null
    remove_sandbox "${popup_pid:-$NVIM_PID}"
}
trap cleanup EXIT

# tmux with the repo's config, its keys for the guides' check
sed -e '/^if "test ! -d ~\/.tmux\/plugins\/tpm"/,+1d' -e "\|^run '~/.tmux/plugins/tpm/tpm'|d" "$TMUX_CONF" >"$SB/tmux.conf"
grep -q "tpm" <(grep -v '^\s*#' "$SB/tmux.conf" | grep -v '@plugin') && fail_early "tmux.conf still runs TPM after stripping it"
mkdir -m 700 "$SB/run"
T -f "$SB/tmux.conf" new-session -d -s t -x 160 -y 40 "sh" || fail_early "tmux didn't start"
TMUX_FORMAT='#{key_table}	#{key_string}	#{key_note}'
{
    T list-keys -N -F "$TMUX_FORMAT"
    T list-keys -N -F "$TMUX_FORMAT" -T copy-mode-vi
} >"$SB/tmux-keys.txt"
PREFIX="$(T show-options -gv prefix)"

# --- The pieces ---------------------------------------------------------

"$SB/nvim.sh" --headless >/dev/null 2>&1 &
NVIM_PID=$!
wait_for 15 test -S "$SB/nvim.sock" || fail_early "Neovim didn't start"

probe="$(nv "luaeval('dofile(_A[1])(_A[2])', ['$HERE/shortcuts_probe.lua', '$HERE/fixtures/tmux-list-keys.txt'])")"
value() { sed -n "s/^$(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g')=//p" <<<"$probe"; }

check "tmux: a key without a note is left out" 6 "$(value tmux.count)"
check "tmux: prefix keys show the prefix" "after the prefix | Split side by side" "$(value 'tmux[C-Space |]')"
check "tmux: keys without the prefix" "no prefix | Focus the pane on the left (Neovim splits first)" "$(value 'tmux[C-h]')"
check "tmux: copy mode keys" "copy mode | Start a selection" "$(value 'tmux[v]')"
check "nvim: a leader map" "normal | Find Files" "$(value 'nvim[<leader>ff]')"
check "nvim: one entry for a map in several modes" "normal, visual | Paste the last copy (safe register 0)" "$(value 'nvim[<leader>p]')"
check "nvim: LSP keys listed without a server" "LSP | Go to References" "$(value 'nvim[grr LSP]')"
check "nvim: LSP leader keys" "LSP | Rename Variable" "$(value 'nvim[<leader>rn LSP]')"
check "nvim: git keys listed outside git" "Git | Next git change" "$(value 'nvim[]c Git]')"
check "nvim: where a plugin spec's key comes from" "lazy.nvim keys of a plugin spec" "$(value 'nvim[<leader>ff].from')"
check "nvim: where a config map with a function comes from" "lua/config/keymaps.lua" "$(value 'nvim[<leader>yc].from')"
check "nvim: what a map with a text rhs runs" ":nohlsearch<CR>" "$(value 'nvim[<Esc>].runs')"

# --- The guides (prefix + N / T) ----------------------------------------

# Every key a guide cites exists in the config. Accepted without checking:
# TPM's and tmux-resurrect's keys (no plugin runs in the test server)
guide() {
    nv "luaeval('dofile(_A[1])(_A[2])', ['$HERE/guide_probe.lua', {'readme': '$1', 'kind': '$2', 'tmux': '$SB/tmux-keys.txt', 'prefix': '$PREFIX', 'allowed': ['$PREFIX I', '$PREFIX U', '$PREFIX C-s', '$PREFIX C-r']}])"
}
check "the tmux guide cites only keys tmux has" "" "$(guide "$TMUX_GUIDE" tmux)"
check "the Neovim guide cites only keys Neovim has" "" "$(guide "$NVIM_DIR/README.md" nvim)"
# The file a popup key opens, with ~ and ${LYNE_DOTS:-...} as the shell would
# see them here (list-keys shows $ escaped)
guide_file() {
    local f
    f="$(T list-keys -T prefix "$1" | grep -o "[^ \"']*README\.md" | tr -d "\\\\")"
    f="${f/#\~/$HOME}"
    f="${f/\$\{LYNE_DOTS:-\$HOME\/.lyne-dots\}/$REPO}"
    echo "$f"
}
for key in N T; do
    file="$(guide_file "$key")"
    check "C-Space $key opens a guide that exists" yes "$([[ -f "$file" ]] && echo yes || echo "no (${file:-no README in the bind})")"
done

kill "$NVIM_PID" 2>/dev/null
wait "$NVIM_PID" 2>/dev/null
NVIM_PID=""
rm -f "$SB/nvim.sock"

# --- The popup ----------------------------------------------------------


# What the popup's Neovim starts with: the sandbox, and its socket in $SB/run
for var in XDG_CONFIG_HOME:config XDG_DATA_HOME:data XDG_STATE_HOME:state XDG_CACHE_HOME:cache XDG_RUNTIME_DIR:run; do
    T set-environment -g "${var%%:*}" "$SB/${var#*:}"
done

attach_client t

T send-keys -c "$CLIENT" -K C-Space
# The popup's command waits for the popup to close, and send-keys with it
T send-keys -c "$CLIENT" -K '?' >/dev/null 2>&1 &
popup_sock() { compgen -G "$SB/run/nvim.*.0" >/dev/null; }
wait_for 15 popup_sock || fail_early "prefix + ? opened no Neovim"
POPUP="$(compgen -G "$SB/run/nvim.*.0" | head -1)"
pv() { nvim --headless --server "$POPUP" --remote-expr "$1" 2>/dev/null; }
prompt() { [[ "$(pv '&filetype')" == TelescopePrompt ]]; }
wait_for 15 prompt
check "prefix + ? opens the search, typing goes to its prompt" TelescopePrompt "$(pv '&filetype')"

count() { pv 'luaeval("require(\"telescope.actions.state\").get_current_picker(vim.api.nvim_get_current_buf()).manager:num_results()")'; }
listed() { [[ "$(count)" -gt 100 ]]; }
wait_for 10 listed
total="$(count)"
check "the list has Neovim's and tmux's keys" yes "$([[ "$total" -gt 100 ]] && echo yes || echo "no ($total)")"

for k in S p l i t Space s i d e; do
    T send-keys -c "$CLIENT" -K "$k"
done
selected() { pv 'luaeval("require(\"telescope.actions.state\").get_selected_entry().value.keys")'; }
first_is_split() { [[ "$(selected)" == "C-Space |" ]]; }
wait_for 5 first_is_split
check "typing \"Split side\" finds tmux's prefix + |" "C-Space |" "$(selected)"

T send-keys -c "$CLIENT" -K Escape
gone() { [[ ! -S "$POPUP" ]]; }
wait_for 5 gone
check "one Escape closes the list and the popup" closed "$([[ -S "$POPUP" ]] && echo open || echo closed)"

exit "$failed"
