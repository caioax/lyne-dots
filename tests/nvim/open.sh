#!/usr/bin/env bash
# lyne nvim open (what Godot runs): with no tmux running it starts one with
# the project's session and Neovim in its only window, opens the file at
# the line and column and, with no client, has the default terminal attach
# (a stand-in that logs). Then, with a client attached elsewhere: the file
# goes to the live Neovim, the client switches to its pane and Hyprland (a
# stand-in hyprctl listing the client's "terminal") focuses that window;
# a project with no Neovim gets one in a new window of its existing session
# or in a new session; a tmux started while tmux-continuum restores (a
# stand-in restore that brings back the project's Neovim) waits for it and
# uses that Neovim. Also --project vs the file's own project, a line below
# 1, quotes in file names, lyne nvim list, and usage errors.
#
# Everything runs in the sandbox: its own HOME (no ~/.tmux.conf, a
# state.json naming the stand-in terminal), tmux's default server under
# TMUX_TMPDIR in the sandbox, Neovim's XDG folders (lib.sh).
#
# Usage: tests/nvim/open.sh   (needs nvim, tmux, jq and the plugins)
#   LYNE_TEST_DOTS=<dir>   another copy of the repo for the lyne CLI

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need_tools nvim tmux jq python3

nvim_sandbox
mkdir -p "$SB/home/.config/quickshell" "$SB/tmt" "$SB/tmt2" "$SB/bin" "$SB/tmpdir"
LYNE="$REPO/local/.local/bin/lyne"
CLI="$NVIM_DIR/local-plugins/project-instance.nvim/lua/project_instance/cli.lua"

# The stand-ins: the terminal and hyprctl log their calls; hyprctl lists one
# window, the pid in $SB/window.pid
cat >"$SB/bin/fake-term" <<EOF
#!/bin/sh
echo "term \$*" >>"$SB/calls.log"
EOF
cat >"$SB/bin/hyprctl" <<EOF
#!/bin/sh
echo "hyprctl \$*" >>"$SB/calls.log"
[ "\$1" = clients ] && printf '[{"pid": %s}]\n' "\$(cat "$SB/window.pid" 2>/dev/null || echo 0)"
exit 0
EOF
cat >"$SB/bin/notify-send" <<EOF
#!/bin/sh
echo "notify-send \$*" >>"$SB/calls.log"
EOF
chmod +x "$SB/bin/"*
: >"$SB/calls.log"
printf '{"apps": {"terminal": {"command": "%s", "desktop": ""}}}\n' "$SB/bin/fake-term" >"$SB/home/.config/quickshell/state.json"

# The environment Godot would give lyne, inside the sandbox
ENVS=(env -u TMUX -u TMUX_PANE -u LYNE_NVIM_SOLO -u LYNE_NVIM_INSTANCE
    HOME="$SB/home" SHELL=/bin/sh PATH="$SB/bin:$PATH" TMPDIR="$SB/tmpdir"
    XDG_CONFIG_HOME="$SB/config" XDG_DATA_HOME="$SB/data" XDG_STATE_HOME="$SB/state"
    XDG_CACHE_HOME="$SB/cache" XDG_RUNTIME_DIR="$SB/run" LYNE_DOTS="${LYNE_TEST_DOTS:-$REPO}"
    LYNE_NVIM_WAIT=30)
lyne() { "${ENVS[@]}" TMUX_TMPDIR="$SB/tmt" HYPRLAND_INSTANCE_SIGNATURE="${HYPR:-}" "$LYNE" "$@"; }
SOCK="$SB/tmt/tmux-$(id -u)/default"
T() { tmux -S "$SOCK" "$@"; }

cleanup() {
    local s
    for s in "$SB"/run/lyne-nvim/*.sock; do
        [[ -S "$s" ]] && nvim --headless --server "$s" --remote-send '<C-\><C-N>:qa!<CR>' 2>/dev/null
    done
    sleep 0.5
    [[ -n "${CLIENT_PID:-}" ]] && kill "$CLIENT_PID" 2>/dev/null
    T kill-server 2>/dev/null
    tmux -S "$SB/tmt2/tmux-$(id -u)/default" kill-server 2>/dev/null
    # Until nothing started in the sandbox runs (a Neovim writing its shada,
    # the stand-in restore): one still writing would bring folders back
    local tries=50
    while pgrep -f "$SB/" >/dev/null && ((tries-- > 0)); do
        sleep 0.1
    done
    remove_sandbox ""
}
trap cleanup EXIT

# The project's socket, and an expression evaluated in its Neovim
socket_of() { "${ENVS[@]}" nvim --clean --headless -l "$CLI" locate --project "$1" | cut -f3; }
at() { nvim --headless --server "$(socket_of "$1")" --remote-expr "$2" 2>/dev/null; }

P="$SB/work/game"
Q="$SB/work/tools"
mkdir -p "$P/scripts" "$Q/.git"
touch "$P/project.godot" "$P/Game.sln"
for f in "$P/scripts/a.txt" "$P/scripts/b.txt" "$P/scripts/it's here.txt" "$Q/t.txt"; do
    printf 'line %s with words\n' 1 2 3 4 5 6 7 8 9 >"$f"
done

# --- No tmux running ---
lyne nvim open --project "$P" "$P/scripts/a.txt" 4 6
check "no tmux: lyne succeeds" 0 "$?"
check "no tmux: the project's session" "game" "$(T list-sessions -F '#{session_name}' 2>/dev/null)"
check "no tmux: Neovim in its only window" 1 "$(T list-windows -t =game -F x 2>/dev/null | wc -l)"
check "no tmux: the window runs Neovim (typed in its shell)" nvim "$(T display -p -t =game: '#{pane_current_command}' 2>/dev/null)"
check "no tmux: in the project folder" "$P" "$(T display -p -t =game: '#{pane_current_path}' 2>/dev/null)"
check "no tmux: the file" "$P/scripts/a.txt" "$(at "$P" 'expand("%:p")')"
check "no tmux: at the line" 4 "$(at "$P" 'line(".")')"
check "no tmux: at the column" 6 "$(at "$P" 'col(".")')"
pane_p="$(T display -p -t =game: '#{pane_id}')"
check "no tmux: Neovim knows its pane" "$pane_p" "$(at "$P" 'luaeval("require(\"project_instance\").state.pane")')"
_term() { grep -q '^term ' "$SB/calls.log"; }
wait_for 5 _term
check "no client: the terminal attaches to the session" "term -e tmux -S $SOCK attach-session -t =game" "$(grep '^term ' "$SB/calls.log")"

# --- A client attached elsewhere (a shell window of another session) ---
T new-session -d -s other -c "$SB/work" sh
attach_client other
echo "$CLIENT_PID" >"$SB/window.pid"
: >"$SB/calls.log"
HYPR=fake lyne nvim open --project "$P" "$P/scripts/b.txt" 7 1
check "live Neovim: the file" "$P/scripts/b.txt" "$(at "$P" 'expand("%:p")')"
check "live Neovim: at the line" 7 "$(at "$P" 'line(".")')"
check "live Neovim: no new window" 1 "$(T list-windows -t =game -F x | wc -l)"
check "live Neovim: the client switches to its pane" "$pane_p" "$(T display -p -t "$CLIENT" '#{pane_id}')"
check "live Neovim: the client's terminal gets the focus" \
    "hyprctl dispatch hl.dsp.focus({ window = \"pid:$CLIENT_PID\" })" "$(grep 'dispatch' "$SB/calls.log")"
check "live Neovim: no terminal opened" "" "$(grep '^term ' "$SB/calls.log")"

# The file's own project (no --project), quotes in the name, no line
T switch-client -c "$CLIENT" -t =other
lyne nvim open "$P/scripts/it's here.txt" -1 -1
check "no --project: the file's project, quotes in the name" "$P/scripts/it's here.txt" "$(at "$P" 'expand("%:p")')"
check "a line below 1: the file's first" 1 "$(at "$P" 'line(".")')"
check "the client follows" "$pane_p" "$(T display -p -t "$CLIENT" '#{pane_id}')"

# --- A project with a session of its own but no Neovim: a new window ---
T new-session -d -s tools -c "$Q" sh
lyne nvim open "$Q/t.txt" 2
check "session without Neovim: a new window" 2 "$(T list-windows -t =tools -F x | wc -l)"
check "session without Neovim: the file" "$Q/t.txt" "$(at "$Q" 'expand("%:p")')"
check "session without Neovim: the new window runs Neovim" nvim "$(T display -p -t =tools:1 '#{pane_current_command}')"
check "session without Neovim: the old window keeps its shell" sh "$(T display -p -t =tools:0 '#{pane_current_command}')"
check "session without Neovim: the client lands on it" "tools" "$(T display -p -c "$CLIENT" '#{client_session}')"

# --- tmux running, no session for the project: one made for it ---
R="$SB/work/.dotfiles.v2"
mkdir -p "$R/.git"
printf 'x\n' >"$R/r.txt"
lyne nvim open "$R/r.txt"
check "new session: named like config/projects.lua" 1 "$(T has-session -t =dotfiles_v2 2>/dev/null && echo 1)"
check "new session: one window" 1 "$(T list-windows -t =dotfiles_v2 -F x | wc -l)"
check "new session: the file" "$R/r.txt" "$(at "$R" 'expand("%:p")')"

# --- lyne nvim list ---
list="$(lyne nvim list)"
check "list: the three projects" 3 "$(wc -l <<<"$list")"
check "list: folder and pane" "$P	$pane_p" "$(grep -F "$P	" <<<"$list" | cut -f1,2)"

# --- Usage errors ---
lyne nvim open >/dev/null 2>&1
check "open without a file fails" 1 "$?"
lyne nvim nope >/dev/null 2>&1
check "an unknown subcommand fails" 1 "$?"

# --- A tmux started while tmux-continuum restores ---
# A stand-in restore (named like continuum's, which lyne waits for) brings
# back the project's Neovim in a window of its session after a while
S2="$SB/work/saved"
mkdir -p "$S2/.git" "$SB/home2/.tmux-continuum/scripts"
printf 'l%s\n' 1 2 3 4 5 >"$S2/s.txt"
cat >"$SB/home2/.tmux-continuum/scripts/continuum_restore.sh" <<EOF
#!/bin/sh
sleep 2
tmux new-window -d -t =saved: -c "$S2" "nvim; exec sh"
EOF
chmod +x "$SB/home2/.tmux-continuum/scripts/continuum_restore.sh"
mkdir -p "$SB/home2/.config"
cp -r "$SB/home/.config/quickshell" "$SB/home2/.config/"
printf 'run-shell -b "%s"\n' "$SB/home2/.tmux-continuum/scripts/continuum_restore.sh" >"$SB/home2/.tmux.conf"
: >"$SB/calls.log"
"${ENVS[@]}" HOME="$SB/home2" TMUX_TMPDIR="$SB/tmt2" "$LYNE" nvim open "$S2/s.txt" 3
T2() { tmux -S "$SB/tmt2/tmux-$(id -u)/default" "$@"; }
check "restore: lyne waited and used the restored Neovim" "$S2/s.txt" "$(at "$S2" 'expand("%:p")')"
check "restore: at the line" 3 "$(at "$S2" 'line(".")')"
check "restore: no Neovim of its own (the restored window and the first)" 2 "$(T2 list-windows -t =saved -F x | wc -l)"
check "restore: the first window still holds its shell" sh "$(T2 display -p -t =saved:0 '#{pane_current_command}')"

exit "$failed"
