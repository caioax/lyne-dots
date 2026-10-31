#!/usr/bin/env bash
# Sessions, Neovim's and tmux's, end to end:
# - Neovim saves its session when it loses the focus or a file is written,
#   and not while no file is open (that would replace the folder's session)
# - tmux-resurrect saves a tmux server whose pane runs Neovim; in a new
#   server it restores it, and the pane's Neovim (started without a file)
#   comes back with the folder's session: its two splits. tmux-continuum is
#   on to restore by itself (it only does when its server is the only one on
#   the machine, so here resurrect's restore runs the way continuum calls it)
# - prefix + X and the shell's tkf close everything and forget the save: the
#   next restore finds nothing
#
# Both servers use their own socket and the repo's tmux.conf without TPM;
# resurrect and continuum (your installed copies) are loaded by hand once
# @resurrect-dir points into the sandbox, so your saves are never read or
# written. The servers start with the sandbox's XDG folders in their
# environment: the panes' Neovim runs in the sandbox of lib.sh, its socket
# in $SB/run.
#
# Usage: tests/nvim/sessions.sh   (needs tmux, nvim, zsh, the plugins and
# TPM's tmux-resurrect and tmux-continuum)
#   LYNE_TEST_NVIM=<dir>       another copy of nvim/.config/nvim (lib.sh)
#   LYNE_TEST_TMUX_CONF=<file> another copy of tmux/.tmux.conf
#   LYNE_TEST_ZSHRC=<file>     another copy of zsh/.zshrc

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
TMUX_CONF="${LYNE_TEST_TMUX_CONF:-$REPO/tmux/.tmux.conf}"
ZSHRC="${LYNE_TEST_ZSHRC:-$REPO/zsh/.zshrc}"
PLUGINS="$HOME/.tmux/plugins"

need_tools tmux nvim zsh python3
for plugin in tmux-resurrect/resurrect.tmux tmux-continuum/continuum.tmux; do
    [[ -f "$PLUGINS/$plugin" ]] || fail_early "missing $PLUGINS/$plugin (prefix + I installs the plugins)"
done

nvim_sandbox
SOCK="$SB/tmux.sock"
T() { tmux -S "$SOCK" "$@"; }

# Neovim quits on its own first (it writes its shada while quitting)
quit_nvims() {
    local s tries=50
    for s in "$SB"/run/nvim.*.0; do
        [[ -S "$s" ]] && nvim --headless --server "$s" --remote-send '<C-\><C-N>:qa!<CR>' 2>/dev/null
    done
    while compgen -G "$SB/run/nvim.*.0" >/dev/null && ((tries-- > 0)); do
        sleep 0.1
    done
    rm -f "$SB"/run/nvim.*.0
}

cleanup() {
    quit_nvims
    T kill-server 2>/dev/null
    remove_sandbox ""
}
trap cleanup EXIT

sed -e '/^if "test ! -d ~\/.tmux\/plugins\/tpm"/,+1d' -e "\|^run '~/.tmux/plugins/tpm/tpm'|d" "$TMUX_CONF" >"$SB/tmux.conf"
grep -q "tpm" <(grep -v '^\s*#' "$SB/tmux.conf" | grep -v '@plugin') && fail_early "tmux.conf still runs TPM after stripping it"

mkdir "$SB/work" "$SB/resurrect"
echo "first file" >"$SB/work/a.txt"
echo "second file" >"$SB/work/b.txt"

# start_server SESSION [continuum]: a server whose panes run sh in the
# sandbox; resurrect (and continuum) loaded once @resurrect-dir is set
start_server() {
    env XDG_CONFIG_HOME="$SB/config" XDG_DATA_HOME="$SB/data" XDG_STATE_HOME="$SB/state" \
        XDG_CACHE_HOME="$SB/cache" XDG_RUNTIME_DIR="$SB/run" SHELL=/bin/sh \
        tmux -S "$SOCK" -f "$SB/tmux.conf" new-session -d -s "$1" -x 160 -y 40 -c "$SB/work" ||
        fail_early "tmux didn't start"
    T set -g @resurrect-dir "$SB/resurrect"
    [[ "$(T show -gv @resurrect-dir)" == "$SB/resurrect" ]] || fail_early "@resurrect-dir isn't in the sandbox"
    T run-shell "$PLUGINS/tmux-resurrect/resurrect.tmux"
    [[ "${2:-}" == continuum ]] && T run-shell "$PLUGINS/tmux-continuum/continuum.tmux"
}

nvim_sock() { compgen -G "$SB/run/nvim.*.0" | head -1; }
nvim_up() { [[ -n "$(nvim_sock)" ]]; }
nv() { nvim --headless --server "$(nvim_sock)" --remote-expr "$1" 2>/dev/null; }
sessions() { find "$SB/state/nvim/sessions" -name '*.vim' 2>/dev/null | wc -l; }

# --- Neovim saving its session -------------------------------------------

start_server t
T send-keys -t t 'nvim' Enter
wait_for 20 nvim_up || fail_early "Neovim didn't start in the pane"
nv 'luaeval("require(\"persistence\") and 1")' >/dev/null
nv 'execute("doautocmd FocusLost")' >/dev/null
check "no file open: losing the focus saves no session" 0 "$(sessions)"

nv 'execute("edit a.txt | vsplit b.txt")' >/dev/null
nv 'execute("doautocmd FocusLost")' >/dev/null
check "losing the focus saves the session" 1 "$(sessions)"
find "$SB/state/nvim/sessions" -name '*.vim' -delete
nv 'execute("write")' >/dev/null
check "writing a file saves the session" 1 "$(sessions)"
check "the session has both files" 2 "$(grep -c '^badd .*[ab]\.txt$' "$(find "$SB/state/nvim/sessions" -name '*.vim' | head -1)")"

# --- tmux saving and restoring --------------------------------------------

T run-shell "$PLUGINS/tmux-resurrect/scripts/save.sh quiet"
check "tmux-resurrect saved the pane running Neovim" 1 "$(grep -c "^pane.*:nvim$" "$SB/resurrect/last" 2>/dev/null)"

quit_nvims
T kill-server
sleep 0.5

# continuum restores on its own only when its server is the only one on the
# machine (yours runs): checked that it's on, then resurrect's restore runs
# the way continuum would call it
start_server boot continuum
check "tmux-continuum restores by itself" on "$(T show -gv @continuum-restore)"
T run-shell "$(T show -gv @resurrect-restore-script-path)"
restored() { T has-session -t t 2>/dev/null; }
wait_for 20 restored
check "tmux-resurrect restores the saved session" yes "$(restored && echo yes || echo no)"
wait_for 30 nvim_up
check "the pane runs Neovim again" yes "$(nvim_up && echo yes || echo no)"
loaded() { [[ "$(nv 'winnr("$")')" == 2 ]]; }
wait_for 15 loaded
check "Neovim comes back with the folder's session (two splits)" "2 a.txt b.txt" \
    "$(nv 'winnr("$")') $(nv 'join(sort(map(filter(range(1, bufnr("$")), "buflisted(v:val)"), "fnamemodify(bufname(v:val), \":t\")")), " ")')"
check "in the pane's folder" "$SB/work" "$(T display -p -t t '#{pane_current_path}')"

# --- Closing everything and forgetting the save ---------------------------

saves() { find "$SB/resurrect" -name 'tmux_resurrect_*.txt' | wc -l; }
kept="$(saves)"
quit_nvims
attach_client t
T send-keys -c "$CLIENT" -K "$(T show-options -gv prefix)"
# confirm-before waits for the answer, and send-keys with it
T send-keys -c "$CLIENT" -K X >/dev/null 2>&1 &
sleep 0.5
T send-keys -c "$CLIENT" -K y
server_gone() { ! T list-sessions >/dev/null 2>&1; }
wait_for 5 server_gone
check "prefix + X (then y) closes every session" yes "$(server_gone && echo yes || echo no)"
check "and forgets the save (resurrect's last)" no "$([[ -e "$SB/resurrect/last" || -L "$SB/resurrect/last" ]] && echo yes || echo no)"
check "the older saves stay on disk" "$kept" "$(saves)"
start_server boot
T run-shell "$(T show -gv @resurrect-restore-script-path)"
sleep 1
check "the next tmux starts empty" no "$(T has-session -t t 2>/dev/null && echo yes || echo no)"
T kill-server

# The shell's tkf (zsh/.zshrc) does the same from outside tmux. Its tmux
# commands go to the default server, so the test gives it one of its own: a
# TMUX_TMPDIR in the sandbox, checked to hold only this test's session
tmpdir="$SB/tmpdir"
mkdir -m 700 "$tmpdir"
D() { env -u TMUX TMUX_TMPDIR="$tmpdir" tmux "$@"; }
D -f "$SB/tmux.conf" new-session -d -s forgetme -c "$SB/work" || fail_early "tmux didn't start"
D set -g @resurrect-dir "$SB/resurrect"
D run-shell "$PLUGINS/tmux-resurrect/scripts/save.sh quiet"
[[ "$(D list-sessions -F '#{session_name}')" == forgetme ]] || fail_early "TMUX_TMPDIR didn't give the test a server of its own"
[[ -L "$SB/resurrect/last" ]] || fail_early "no save to forget"
tkf="$(sed -n '/^tkf() {/,/^}/p' "$ZSHRC")"
[[ -n "$tkf" ]] || fail_early "no tkf in zsh/.zshrc"
env -u TMUX TMUX_TMPDIR="$tmpdir" zsh -fc "$tkf; tkf"
check "tkf closes every session" no "$(D has-session 2>/dev/null && echo yes || echo no)"
check "tkf forgets the save" no "$([[ -e "$SB/resurrect/last" || -L "$SB/resurrect/last" ]] && echo yes || echo no)"

# An interactive zsh starts with status 0: `exit` as the first command must
# end it cleanly (Neovim's terminal reports a non-zero exit as an error)
mkdir -p "$SB/zdot"
ln -sf "$ZSHRC" "$SB/zdot/.zshrc"
env -u TMUX ZDOTDIR="$SB/zdot" zsh -i -c exit </dev/null >/dev/null 2>&1
check "zsh: exit as the first command ends with 0" 0 "$?"

exit "$failed"
