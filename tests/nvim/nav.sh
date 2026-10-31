#!/usr/bin/env bash
# Ctrl/Alt + h/j/k/l between Neovim's splits and tmux's panes, for real:
# a tmux server of its own (its own socket, the repo's tmux.conf without TPM,
# so no plugin and no continuum save runs) with a shell pane on the left and
# Neovim with the repo's config on the right, split in two. A client attached
# through a pty types the keys (send-keys -K goes through the key tables).
# The same way: surround's keys (S, ys, cs, ds) next to the remapped y.
#
# Neovim runs in the sandbox of lib.sh. Only the plugins already installed
# are used: no file is opened, so nothing that installs (Mason, Treesitter
# parsers on demand) starts.
#
# Usage: tests/nvim/nav.sh   (needs tmux, nvim, python3 and the plugins)
#   NAV_DEBUG=1                print the checkhealth report
#   LYNE_TEST_NVIM=<dir>       another copy of nvim/.config/nvim (lib.sh)
#   LYNE_TEST_TMUX_CONF=<file> another copy of tmux/.tmux.conf
#   LYNE_TEST_KITTY_CONF=<file> another copy of kitty/.config/kitty/kitty.conf

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
TMUX_CONF="${LYNE_TEST_TMUX_CONF:-$REPO/tmux/.tmux.conf}"

need_tools tmux nvim python3

nvim_sandbox
SOCK="$SB/tmux.sock"
CLIENT_PID=""

T() { tmux -S "$SOCK" "$@"; }

cleanup() {
    local nvim_pid
    nvim_pid="$(T display -p -t t:1.2 '#{pane_pid}' 2>/dev/null)"
    [[ -n "$CLIENT_PID" ]] && kill "$CLIENT_PID" 2>/dev/null
    T kill-server 2>/dev/null
    remove_sandbox "$nvim_pid"
}
trap cleanup EXIT

# tmux.conf without TPM: its bootstrap clones, and continuum would save
# this session over your last one
sed -e '/^if "test ! -d ~\/.tmux\/plugins\/tpm"/,+1d' -e "\|^run '~/.tmux/plugins/tpm/tpm'|d" "$TMUX_CONF" >"$SB/tmux.conf"
grep -q "tpm" <(grep -v '^\s*#' "$SB/tmux.conf" | grep -v '@plugin') && fail_early "tmux.conf still runs TPM after stripping it"


active() { T display -p -t t '#{pane_index}'; }
key() {
    T send-keys -c "$CLIENT" -K "$1"
    sleep 0.6
}

T -f "$SB/tmux.conf" new-session -d -s t -x 160 -y 40 "sh" || fail_early "tmux didn't start"
T split-window -h -t t "$SB/nvim.sh"
T resize-pane -t t:1.1 -x 60

pane_is_vim() { [[ "$(T show -p -t t:1.2 -v @pane-is-vim 2>/dev/null)" == 1 ]]; }
wait_for 20 pane_is_vim
check "Neovim tells tmux it runs in the pane (@pane-is-vim)" 1 "$(T show -p -t t:1.2 -v @pane-is-vim 2>/dev/null)"
wait_for 10 test -S "$SB/nvim.sock" || fail_early "Neovim didn't start"
check "nvim-cmp waits for insert mode (not loaded at startup)" 1 "$(nv 'luaeval("package.loaded.cmp == nil and 1 or 0")')"

attach_client t

# which-key: loaded once Neovim has a UI (VeryLazy, so not in headless
# tests), and Space shows the groups
wk_loaded() { [[ "$(nv 'luaeval("package.loaded[\"which-key\"] and 1 or 0")')" == 1 ]]; }
wait_for 10 wk_loaded
check "which-key loads with the UI" 1 "$(nv 'luaeval("package.loaded[\"which-key\"] and 1 or 0")')"
key Space
popup="$(T capture-pane -p -t t:1.2)"
[[ -n "${NAV_DEBUG:-}" ]] && printf "%s\n" "$popup"
check "Space shows the leader groups (Find, Git, Sessions)" 3 "$(grep -cE '\+(Find|Git|Sessions) ' <<<"$popup")"
key Escape

# Surround (nvim-surround), typed through tmux with which-key loaded. The
# system clipboard is a stand-in: y's copies land in g:test_clip, not yours
cat >"$SB/clip.lua" <<'EOF'
local function copy(lines)
    vim.g.test_clip = table.concat(lines, "\n")
end
local function paste()
    return { vim.split(vim.g.test_clip or "", "\n"), "v" }
end
vim.g.clipboard = { name = "test", copy = { ["+"] = copy, ["*"] = copy }, paste = { ["+"] = paste, ["*"] = paste } }
EOF
nv "execute('luafile $SB/clip.lua')" >/dev/null
nv 'execute("enew | call setline(1, \"word\")")' >/dev/null
typed() {
    T send-keys -c "$CLIENT" -K "$@"
    sleep 0.6
}
line() { nv 'getline(1)'; }
T send-keys -c "$CLIENT" -K y i w
sleep 0.3
check "yiw still copies to the system clipboard, without waiting for ys" "word" "$(nv 'get(g:, "test_clip", "")')"
typed v i w S '"'
check 'a selection + S" wraps it in quotes' '"word"' "$(line)"
typed c s '"' "'"
check "cs\"' changes the quotes" "'word'" "$(line)"
typed d s "'"
check "ds' deletes them" "word" "$(line)"
typed y s i w ']'
check "ysiw] wraps the word in brackets" "[word]" "$(line)"
typed Escape
nv 'execute("bwipeout!")' >/dev/null

# Two Neovim windows side by side, the cursor in the right one
nv 'execute("vsplit | wincmd l")' >/dev/null
# Floating windows (which-key, a notification) don't count
splits() { nv 'luaeval("#vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == \"\" end, vim.api.nvim_tabpage_list_wins(0))")'; }
check "Neovim has two windows, the right one focused" "2 2" "$(splits) $(nv 'winnr()')"

key C-h
check "Ctrl+h moves to Neovim's left window first" "1 2" "$(nv 'winnr()') $(active)"
key C-h
check "Ctrl+h again leaves Neovim for the tmux pane on the left" 1 "$(active)"
key C-l
check "Ctrl+l from the shell goes back to Neovim" 2 "$(active)"
key C-l
check "Ctrl+l inside Neovim moves to its right window" "2 2" "$(nv 'winnr()') $(active)"

# Resizing: the shell pane grows by 3 columns; Neovim gets Alt + h/j/k/l
key C-h
key C-h
before="$(T display -p -t t:1.1 '#{pane_width}')"
key M-l
check "Alt+l in the shell pane grows it to the right" "$((before + 3))" "$(T display -p -t t:1.1 '#{pane_width}')"

# Copy mode keeps moving between panes
T copy-mode -t t:1.1
key C-l
check "Ctrl+l in copy mode moves to the pane on the right" 2 "$(active)"

# smart-splits' own check of its backend
nv 'execute("checkhealth smart-splits")' >/dev/null
health="$(nv 'join(getline(1, "$"), "\n")')"
errors="$(grep -c 'ERROR' <<<"$health")"
[[ -n "${NAV_DEBUG:-}" ]] && printf '%s\n' "$health"
check "checkhealth smart-splits: no errors" 0 "$errors"
check "checkhealth smart-splits: the tmux backend is in use" 1 "$(grep -c 'smart-splits-backend-tmux: in use' <<<"$health")"
[[ "$errors" != 0 ]] && grep 'ERROR' <<<"$health" | sed 's/^/    /'

# Ctrl+/ reaches Neovim as Ctrl+_ (0x1f, what terminals send): it opens the
# terminal split below, and from inside it hides it again
T select-pane -t t:1.2
terms() { nv 'luaeval("#vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].buftype == \"terminal\" end, vim.api.nvim_list_wins())")'; }
feed_client t '\x1f'
_term_open() { [[ "$(terms)" == 1 ]]; }
wait_for 5 _term_open
check "Ctrl+/ (sent as Ctrl+_) opens the terminal split" 1 "$(terms)"
check "the terminal takes the typing (terminal mode)" t "$(nv 'mode()')"
# From inside it, Ctrl+k / Ctrl+j move between it and the split above
# (through tmux's binds: the pane runs Neovim)
in_term() { nv 'luaeval("vim.bo.buftype == \"terminal\" and 1 or 0")'; }
feed_client t '\x0b'
_left_term() { [[ "$(in_term)" == 0 ]]; }
wait_for 5 _left_term
check "Ctrl+k from inside the terminal goes to the split above" 0 "$(in_term)"
check "the terminal stays open" 1 "$(terms)"
feed_client t '\x0a'
_back_term() { [[ "$(in_term)" == 1 && "$(nv 'mode()')" == t ]]; }
wait_for 5 _back_term
check "Ctrl+j goes back into it, ready to type" "1 t" "$(in_term) $(nv 'mode()')"
feed_client t '\x1f'
_term_hidden() { [[ "$(terms)" == 0 ]]; }
wait_for 5 _term_hidden
check "Ctrl+/ from inside the terminal hides it" 0 "$(terms)"

# kitty sends Ctrl+Shift+h/j/k/l and Ctrl+Alt+Shift+h/l as CSI u
# (kitty.conf), which tmux reads apart from Ctrl+h/l: the bytes kitty.conf
# sends, fed to tmux like a terminal does
KITTY_CONF="${LYNE_TEST_KITTY_CONF:-$REPO/kitty/.config/kitty/kitty.conf}"
sends() { sed -n "s/^map $1 send_text all //p" "$KITTY_CONF"; }
check "kitty sends Ctrl+Alt+Shift+h and l" 2 "$( { sends ctrl+alt+shift+h; sends ctrl+alt+shift+l; } | grep -c .)"
T new-window -t t: -n B sh
T new-window -t t: -n C sh
T select-window -t t:B
order() { T list-windows -t t -F '#{window_name}#{?window_active,*,}' | tr '\n' ' '; }
T rename-window -t "t:$(T list-windows -t t -F '#{window_index}' | head -1)" A
check "windows before" "A B* C " "$(order)"
feed_client t "$(sends ctrl+alt+shift+h)"
check "Ctrl+Alt+Shift+h moves the window left, still focused" "B* A C " "$(order)"
feed_client t "$(sends ctrl+alt+shift+h)"
check "at the left end it stays" "B* A C " "$(order)"
feed_client t "$(sends ctrl+alt+shift+l)"
feed_client t "$(sends ctrl+alt+shift+l)"
check "Ctrl+Alt+Shift+l twice moves it to the right end" "A C B* " "$(order)"
feed_client t "$(sends ctrl+alt+shift+l)"
check "at the right end it stays" "A C B* " "$(order)"
feed_client t '\x1b\x08'
check "plain Ctrl+Alt+h still goes to the previous window" "A C* B " "$(order)"
# Ctrl+Shift+l swaps the pane with the one on its right (window A: the
# shell and Neovim side by side)
T select-window -t t:A
T select-pane -t t:A.1
left="$(T display -p -t t:A.1 '#{pane_id}')"
feed_client t "$(sends ctrl+shift+l)"
check "Ctrl+Shift+l swaps the pane with the one on the right" "$left" "$(T display -p -t t:A.2 '#{pane_id}')"

exit "$failed"
