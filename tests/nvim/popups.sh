#!/usr/bin/env bash
# tmux's popups, for real, in a tmux server of its own (the repo's tmux.conf
# without TPM, keys typed through an attached client):
# - prefix + G runs lazygit in the pane's folder (a stand-in that logs it)
# - prefix + S shows the scratch terminal (the session "scratch", no status
#   bar, in the pane's folder); the same key from inside hides it, and
#   showing it again brings back the same terminal
# - prefix + P lists the sessions (not the scratch one) and the project
#   folders (fake ones: LYNE_PROJECT_ROOTS and LYNE_DOTS point into the
#   sandbox); a folder starts its session there and switches to it, a
#   session switches back; Escape goes to normal mode (j / k move), a
#   second one closes it. Its Neovim runs in the sandbox of lib.sh
#
# Usage: tests/nvim/popups.sh   (needs tmux, nvim, python3 and the plugins)
#   LYNE_TEST_NVIM=<dir>       another copy of nvim/.config/nvim (lib.sh)
#   LYNE_TEST_TMUX_CONF=<file> another copy of tmux/.tmux.conf

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
TMUX_CONF="${LYNE_TEST_TMUX_CONF:-$REPO/tmux/.tmux.conf}"

need_tools tmux nvim python3

# Run from inside tmux, the server below would inherit that client's TMUX
# and prefix + P's popup would never open
unset TMUX TMUX_PANE

nvim_sandbox
SOCK="$SB/tmux.sock"
CLIENT_PID=""
T() { tmux -S "$SOCK" "$@"; }

cleanup() {
    [[ -n "$CLIENT_PID" ]] && kill "$CLIENT_PID" 2>/dev/null
    T kill-server 2>/dev/null
    remove_sandbox ""
}
trap cleanup EXIT

sed -e '/^if "test ! -d ~\/.tmux\/plugins\/tpm"/,+1d' -e "\|^run '~/.tmux/plugins/tpm/tpm'|d" "$TMUX_CONF" >"$SB/tmux.conf"
grep -q "tpm" <(grep -v '^\s*#' "$SB/tmux.conf" | grep -v '@plugin') && fail_early "tmux.conf still runs TPM after stripping it"

# Stand-ins first in the panes' and popups' PATH
mkdir -p "$SB/bin" "$SB/work" "$SB/projects/alpha" "$SB/projects/beta.app" "$SB/.lyne-dots"
cat >"$SB/bin/lazygit" <<EOF
#!/bin/sh
pwd >"$SB/lazygit.cwd"
echo \$\$ >"$SB/lazygit.pid"
exec sleep 60
EOF
chmod +x "$SB/bin/lazygit"

env PATH="$SB/bin:$PATH" SHELL=/bin/sh LYNE_PROJECT_ROOTS="$SB/projects" LYNE_DOTS="$SB/.lyne-dots" \
    XDG_CONFIG_HOME="$SB/config" XDG_DATA_HOME="$SB/data" XDG_STATE_HOME="$SB/state" \
    XDG_CACHE_HOME="$SB/cache" XDG_RUNTIME_DIR="$SB/run" \
    tmux -S "$SOCK" -f "$SB/tmux.conf" new-session -d -s t -x 160 -y 40 -c "$SB/work" || fail_early "tmux didn't start"
attach_client t
PREFIX="$(T show-options -gv prefix)"

# key CLIENT KEY: typed in that client; a popup's command waits for the
# popup to close, so it's sent in the background
key() {
    T send-keys -c "$1" -K "$PREFIX"
    T send-keys -c "$1" -K "$2" >/dev/null 2>&1 &
    sleep 0.8
}

# --- prefix + G: lazygit --------------------------------------------------

key "$CLIENT" G
wait_for 5 test -f "$SB/lazygit.cwd"
check "prefix + G runs lazygit in the pane's folder" "$SB/work" "$(cat "$SB/lazygit.cwd" 2>/dev/null)"
# Quitting lazygit closes the popup
kill "$(cat "$SB/lazygit.pid")" 2>/dev/null
lazygit_gone() { ! kill -0 "$(cat "$SB/lazygit.pid")" 2>/dev/null; }
wait_for 5 lazygit_gone
sleep 0.5

# --- prefix + S: the scratch terminal -------------------------------------

inner() { T list-clients -F '#{client_name} #{client_session}' | awk '$2 == "scratch" { print $1 }'; }
shown() { [[ -n "$(inner)" ]]; }

key "$CLIENT" S
wait_for 5 shown
check "prefix + S shows the scratch terminal" yes "$(shown && echo yes || echo no)"
check "it has no status bar of its own" off "$(T show-options -t scratch -v status 2>/dev/null)"
check "it starts in the pane's folder" "$SB/work" "$(T display -p -t scratch '#{pane_current_path}')"
first_pane="$(T display -p -t scratch '#{pane_id}')"
T send-keys -t scratch "echo kept >$SB/scratch.mark" Enter

key "$(inner)" S
hidden() { [[ -z "$(inner)" ]]; }
wait_for 5 hidden
check "prefix + S inside it hides it" yes "$(hidden && echo yes || echo no)"
check "the terminal keeps running" yes "$(T has-session -t scratch 2>/dev/null && echo yes || echo no)"

key "$CLIENT" S
wait_for 5 shown
check "prefix + S again shows the same terminal" "$first_pane kept" \
    "$(T display -p -t scratch '#{pane_id}') $(cat "$SB/scratch.mark" 2>/dev/null)"
key "$(inner)" S
wait_for 5 hidden

# --- prefix + P: projects and sessions ------------------------------------

popup_sock() { compgen -G "$SB/run/nvim.*.0" | head -1; }
popup_up() { [[ -n "$(popup_sock)" ]]; }
popup_gone() { [[ -z "$(popup_sock)" ]]; }
pv() { nvim --headless --server "$(popup_sock)" --remote-expr "$1" 2>/dev/null; }
prompt() { [[ "$(pv '&filetype')" == TelescopePrompt ]]; }
results() { pv 'luaeval("require(\"telescope.actions.state\").get_current_picker(vim.api.nvim_get_current_buf()).manager:num_results()")'; }
session() { T display -p -c "$CLIENT" '#{client_session}'; }
type_keys() {
    local k
    for k in "$@"; do
        T send-keys -c "$CLIENT" -K "$k"
    done
    sleep 0.6
}

key "$CLIENT" P
wait_for 15 popup_up && wait_for 15 prompt
check "prefix + P opens the list" TelescopePrompt "$(pv '&filetype')"
listed() { [[ "$(results)" == 4 ]]; }
wait_for 5 listed
check "it lists the session t and the folders alpha, beta.app, lyne-dots (not scratch)" 4 "$(results)"

type_keys b e t a Enter
wait_for 5 popup_gone
check "a folder starts its session (name without the dot) and switches to it" beta_app "$(session)"
check "the new session is in the folder" "$SB/projects/beta.app" "$(T list-sessions -F '#{session_name} #{session_path}' | sed -n 's/^beta_app //p')"
check "the popup closes" yes "$(popup_gone && echo yes || echo no)"

key "$CLIENT" P
wait_for 15 popup_up && wait_for 15 prompt
wait_for 5 listed
# t is the session in the folder "work"
type_keys w o r k Enter
wait_for 5 popup_gone
check "a session switches back to it, no new session" "t 3" "$(session) $(T list-sessions | wc -l)"

# Escape goes to normal mode, where j / k move through the list; a second
# Escape closes it
key "$CLIENT" P
wait_for 15 popup_up && wait_for 15 prompt
wait_for 5 listed
selected() { pv 'luaeval("require(\"telescope.actions.state\").get_selected_entry().value.name")'; }
first="$(selected)"
type_keys Escape
check "Escape: normal mode, the list stays" "n open" "$(pv 'mode()') $(popup_up && echo open)"
type_keys j
check "j moves to another entry" 1 "$([[ "$(selected)" != "$first" && -n "$(selected)" ]] && echo 1)"
type_keys k
check "k moves back" "$first" "$(selected)"
type_keys Escape
wait_for 5 popup_gone
check "a second Escape closes the popup" yes "$(popup_gone && echo yes || echo no)"

exit "$failed"
