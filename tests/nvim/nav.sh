#!/usr/bin/env bash
# Ctrl/Alt + h/j/k/l between Neovim's splits and tmux's panes, for real:
# a tmux server of its own (its own socket, the repo's tmux.conf without TPM,
# so no plugin and no continuum save runs) with a shell pane on the left and
# Neovim with the repo's config on the right, split in two. A client attached
# through a pty types the keys (send-keys -K goes through the key tables).
#
# Neovim runs in the sandbox of lib.sh. Only the plugins already installed
# are used: no file is opened, so nothing that installs (Mason, Treesitter
# parsers on demand) starts.
#
# Usage: tests/nvim/nav.sh   (needs tmux, nvim, python3 and the plugins)
#   NAV_DEBUG=1                print the checkhealth report
#   LYNE_TEST_NVIM=<dir>       another copy of nvim/.config/nvim (lib.sh)
#   LYNE_TEST_TMUX_CONF=<file> another copy of tmux/.tmux.conf

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

# The client: a pty with tmux attached, its output thrown away
cat >"$SB/client.py" <<'EOF'
import fcntl, os, pty, select, struct, sys, termios
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("tmux", ["tmux", "-S", sys.argv[1], "attach", "-t", "t"])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 160, 0, 0))
while True:
    r, _, _ = select.select([fd], [], [], 1)
    if r:
        try:
            if not os.read(fd, 65536):
                break
        except OSError:
            break
EOF

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

python3 "$SB/client.py" "$SOCK" &
CLIENT_PID=$!
attached() { [[ -n "$(T list-clients -F '#{client_name}')" ]]; }
wait_for 5 attached || fail_early "no tmux client"
CLIENT="$(T list-clients -F '#{client_name}' | head -1)"

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

# Two Neovim windows side by side, the cursor in the right one
nv 'execute("vsplit | wincmd l")' >/dev/null
check "Neovim has two windows, the right one focused" "2 2" "$(nv 'winnr("$") . " " . winnr()')"

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

exit "$failed"
