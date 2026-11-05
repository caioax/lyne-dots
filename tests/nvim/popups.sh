#!/usr/bin/env bash
# tmux's popups, for real, in a tmux server of its own (the repo's tmux.conf
# without TPM, keys typed through an attached client):
# - prefix + G runs lazygit in the pane's folder (a stand-in that logs it)
# - prefix + S shows the scratch terminal (the session "scratch", no status
#   bar, in the pane's folder); the same key from inside hides it, and
#   showing it again brings back the same terminal; exit in it closes the
#   popup (no other session shown inside)
# - prefix + P lists the sessions (not the scratch one) and the project
#   folders (fake ones: LYNE_PROJECT_ROOTS and LYNE_DOTS point into the
#   sandbox; a folder that isn't a project lists the projects inside it, three
#   levels down at most, not in node_modules; inside a project only a .root
#   makes another one, within the same three levels); a folder starts its session there and switches to it, a
#   session switches back; Escape goes to normal mode (j / k move), a
#   second one closes it. Ctrl+d (dd in normal mode) hides a folder, saved in
#   Neovim's state folder, Ctrl+h (H) shows the hidden ones and dd brings one
#   back; dd on a session closes it after a y (n keeps it). Its Neovim runs in the sandbox of lib.sh
# - prefix + C asks a name and starts that session in the pane's folder,
#   switching to it; a name already there switches, an empty one makes
#   nothing (no numbered sessions); closing the client's session takes it
#   to the one used last (detach-on-destroy off)
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
# A project with one inside it, and a group of projects: one, sub/two (3
# levels down), sub/deep/far (4: too deep) and one in node_modules
G="$SB/projects/group"
mkdir -p "$SB/projects/game/.git" "$SB/projects/game/inner/.git" "$G/one/.git" "$G/sub/two" \
    "$G/sub/deep/far/.git" "$G/node_modules/pkg/.git"
touch "$G/sub/two/.root"
# A .root inside a project: game/part and group/one/lib (3 levels down) count;
# game/a/b/c, group/one/x/y and group/sub/two/three (4: too deep) don't
mkdir -p "$SB/projects/game/part" "$SB/projects/game/a/b/c" "$G/one/lib" "$G/one/x/y" "$G/sub/two/three"
touch "$SB/projects/game/part/.root" "$SB/projects/game/a/b/c/.root" "$G/one/lib/.root" "$G/one/x/y/.root" \
    "$G/sub/two/three/.root"
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

# exit in it ends the scratch session and closes the popup; it never shows
# another session (detach-on-destroy is off for the others)
key "$CLIENT" S
wait_for 5 shown
T send-keys -t scratch 'exit' Enter
scratch_gone() { ! T has-session -t =scratch 2>/dev/null; }
wait_for 5 scratch_gone
sleep 0.5
check "exit in the scratch terminal closes the popup, no other session in it" "1 t" \
    "$(T list-clients | wc -l) $(T display -p -c "$CLIENT" '#{client_session}')"

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
listed() { [[ "$(results)" == 9 ]]; }
wait_for 5 listed
check "it lists the session t and the folders alpha, beta.app, game, part, one, lib, two, lyne-dots (not scratch)" 9 "$(results)"
check "folders: a group gives its projects, a project only the inner ones with a .root" \
    "alpha beta.app game game/part group/one group/one/lib group/sub/two .lyne-dots" \
    "$(pv 'luaeval("table.concat(vim.tbl_map(function(d) return (d:gsub(\"^'"$SB"'/projects/\", \"\"):gsub(\"^'"$SB"'/\", \"\")) end, require(\"config.projects\").folders()), \" \")")')"

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
check "a session switches back to it, no new session" "t 2" "$(session) $(T list-sessions | wc -l)"

# Escape goes to normal mode, where j / k move through the list; a second
# Escape closes it
key "$CLIENT" P
wait_for 15 popup_up && wait_for 15 prompt
wait_for 5 listed
selected() { pv 'luaeval("require(\"telescope.actions.state\").get_selected_entry().value.name")'; }
selected_kind() { pv 'luaeval("require(\"telescope.actions.state\").get_selected_entry().value.kind")'; }
_not_hidden() { [[ "$(cat "$HIDDEN" 2>/dev/null)" == "[]" ]]; }
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

# Hiding a folder, showing the hidden ones, bringing one back; closing a
# session after a y/n
HIDDEN="$SB/state/nvim/lyne-projects-hidden.json"
open_list() {
    key "$CLIENT" P
    wait_for 15 popup_up && wait_for 15 prompt
    wait_for 5 listed
}
results_are() { [[ "$(results)" == "$1" ]]; }
open_list
type_keys a l p h a
wait_for 5 results_are 1
type_keys C-d
wait_for 5 results_are 0
check "Ctrl+d hides the folder" 0 "$(results)"
check "the hidden folder is saved" "[\"$SB/projects/alpha\"]" "$(cat "$HIDDEN" 2>/dev/null)"
type_keys C-h
wait_for 5 results_are 1
check "Ctrl+h shows it, marked hidden" "1 hidden" "$(results) $(selected_kind)"
type_keys Escape d d
wait_for 5 _not_hidden
check "dd on a hidden one brings it back" "[]" "$(cat "$HIDDEN" 2>/dev/null)"
type_keys Escape
wait_for 5 popup_gone
open_list
check "brought back: in a new list again" 9 "$(results)"
type_keys Escape Escape
wait_for 5 popup_gone

T new-session -d -s doomed -c "$SB/work"
open_list
type_keys d o o m e d
wait_for 5 results_are 1
type_keys Escape d d n
check "dd on a session, n: it stays" 1 "$(T has-session -t =doomed 2>/dev/null && echo 1)"
type_keys d d y
_doomed_gone() { ! T has-session -t =doomed 2>/dev/null; }
wait_for 5 _doomed_gone
check "dd on a session, y: it closes" 1 "$(_doomed_gone && echo 1)"
check "the list stays open" "open n" "$(popup_up && echo open) $(pv 'mode()')"
type_keys Escape
wait_for 5 popup_gone

# --- prefix + C: a new session, named -------------------------------------

# prefix + C asks the name in the status line; NAME typed, then Enter (the
# key waits for the prompt to close, like a popup's)
new_session() {
    key "$CLIENT" C
    local i
    for ((i = 0; i < ${#1}; i++)); do T send-keys -c "$CLIENT" -K "${1:i:1}"; done
    T send-keys -c "$CLIENT" -K Enter
    sleep 0.6
}
count() { T list-sessions | wc -l; }
before="$(count)"

new_session ""
check "prefix + C with no name makes nothing" "t $before" "$(session) $(count)"

T send-keys -t t "cd $SB/projects/alpha" Enter
sleep 0.5
new_session notes
check "prefix + C makes the named session and switches to it" "notes $((before + 1))" "$(session) $(count)"
check "it starts in the pane's folder" "$SB/projects/alpha" "$(T display -p -t =notes: '#{pane_current_path}')"

T switch-client -c "$CLIENT" -t =t
new_session notes
check "a name already there switches to it, no new session" "notes $((before + 1))" "$(session) $(count)"

# Closing the session the client is in (the shell's tmq, x in prefix + s)
# takes it to the one used last, not out of tmux
T kill-session -t =notes
sleep 0.5
check "closing its session takes the client to the one used last" "t $before" "$(session) $(count)"

exit "$failed"
