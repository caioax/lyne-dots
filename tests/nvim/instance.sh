#!/usr/bin/env bash
# One Neovim per project (local-plugins/project-instance.nvim): the first
# Neovim opened in a project listens on that project's socket in
# $XDG_RUNTIME_DIR/lyne-nvim (the sandbox's), found from the first file (the
# nearest folder with project.godot, a *.sln or .git, else the file's
# folder) or the current folder; a second one in the same project leaves it
# to the first, a socket left by a killed Neovim is taken over, and the
# Neovims that are never a project's (LYNE_NVIM_SOLO, no UI, -R/-d/stdin,
# git's files and temp files, $TMPDIR here) don't touch it. The session name matches
# config/projects.lua's.
#
# The Neovims run headless with LYNE_NVIM_INSTANCE=1 (headless ones are
# skipped otherwise); each one is driven through its own --listen socket.
#
# Usage: tests/nvim/instance.sh   (needs nvim and the plugins)
#   LYNE_TEST_NVIM=<dir>   another copy of nvim/.config/nvim (lib.sh)

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need_tools nvim python3

nvim_sandbox
PIDS=()

cleanup() {
    local pid
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    for pid in "${PIDS[@]}"; do
        remove_sandbox_wait "$pid"
    done
    rm -rf "$SB"
}
remove_sandbox_wait() {
    local tries=50
    while kill -0 "$1" 2>/dev/null && ((tries-- > 0)); do
        sleep 0.1
    done
}
trap cleanup EXIT

cat >"$SB/inst.sh" <<EOF
#!/bin/sh
# inst.sh CONTROL-SOCKET ARGS...: a headless Neovim of the sandbox that
# counts as one with a UI
ctl="\$1"
shift
export XDG_CONFIG_HOME="$SB/config" XDG_DATA_HOME="$SB/data" XDG_STATE_HOME="$SB/state" XDG_CACHE_HOME="$SB/cache" XDG_RUNTIME_DIR="$SB/run"
export LYNE_NVIM_INSTANCE="\${LYNE_NVIM_INSTANCE-1}"
# The sandbox lives in /tmp: its own temp folder, or every file is a temp file
export TMPDIR="$SB/tmpdir"
exec nvim --headless --listen "\$ctl" "\$@"
EOF
chmod +x "$SB/inst.sh"

# start NAME DIR ARGS...: a Neovim started in DIR, reached as NAME
start() {
    local name="$1" dir="$2"
    shift 2
    (cd "$dir" && exec env -u TMUX -u LYNE_NVIM_SOLO TMUX_PANE="%$name" "$SB/inst.sh" "$SB/$name.ctl" "$@") \
        </dev/null >/dev/null 2>&1 &
    PIDS+=($!)
    LAST_PID=$!
    _up() { [[ "$(at "$name" '1')" == 1 ]]; }
    wait_for 15 _up || fail_early "Neovim $name didn't start"
}
# at NAME EXPR: evaluated in that Neovim
at() { nvim --headless --server "$SB/$1.ctl" --remote-expr "$2" 2>/dev/null; }
# state NAME FIELD: the plugin's state field (booleans as 1/0)
state() {
    at "$1" "luaeval('(function(v) if type(v) == \"boolean\" then return v and 1 or 0 end return v or \"\" end)(require(\"project_instance\").state.$2)')"
}
stop() {
    at "$1" 'execute("qa!")' >/dev/null
    remove_sandbox_wait "$2"
}

P="$SB/work/game"
mkdir -p "$P/scripts/enemy" "$SB/work/plain/sub" "$SB/work/repo/.git" "$SB/work/repo/src" "$SB/work/sln" "$SB/tmpdir"
touch "$P/project.godot" "$P/Game.sln" "$P/scripts/enemy/Enemy.cs" "$SB/work/sln/App.sln" "$SB/work/repo/src/x.lua"
touch "$SB/work/repo/.git/COMMIT_EDITMSG"
# Same folder name elsewhere: its own socket
mkdir -p "$SB/other/game" && touch "$SB/other/game/project.godot"

# A project from a file deep inside it, started from another folder
start a "$SB/work/plain" "$P/scripts/enemy/Enemy.cs"
check "root: the nearest folder with project.godot" "$P" "$(state a root)"
check "the first Neovim owns the project's socket" 1 "$(state a owner)"
sock="$(state a socket)"
check "socket in the runtime folder, named after the session" "$SB/run/lyne-nvim/game-" "${sock%????????.sock}"
check "socket listens" yes "$([[ -S "$sock" ]] && echo yes)"
check "pane recorded" "%a" "$(state a pane)"
check "socket folder is private" 700 "$(stat -c %a "$SB/run/lyne-nvim")"
check ":ProjectInstance exists" 2 "$(at a 'exists(":ProjectInstance")')"
check "info() answers on the socket with the pid" "$(state a root)" \
    "$(nvim --headless --server "$sock" --remote-expr 'luaeval("require(\"project_instance\").info().root")' 2>/dev/null)"

# A second Neovim in the same project (no file, from a subfolder)
start b "$P/scripts"
check "same project from a subfolder" "$P" "$(state b root)"
check "second Neovim doesn't own it" 0 "$(state b owner)"
check "second Neovim sees the live one" 1 "$(state b other)"
check "the socket still reaches the first" "%a" \
    "$(nvim --headless --server "$sock" --remote-expr 'luaeval("require(\"project_instance\").state.pane")' 2>/dev/null)"
pid_b=$LAST_PID
stop b "$pid_b"

# Other roots
start c "$SB/work/repo/src"
check "root: .git" "$SB/work/repo" "$(state c root)"
start d "$SB/work" "$SB/work/sln/New.cs"
check "root: a *.sln (file not created yet)" "$SB/work/sln" "$(state d root)"
start e "$SB/work/plain/sub"
check "root: no marker, the current folder" "$SB/work/plain/sub" "$(state e root)"
start f "$SB" "$SB/work/plain/new/dir/n.txt"
check "root: new file in new folders, its nearest existing folder" "$SB/work/plain" "$(state f root)"
start g "$SB/other/game"
check "same folder name elsewhere: another socket" 1 "$([[ "$(state g socket)" != "$sock" ]] && echo 1)"
check "same folder name elsewhere: owns it" 1 "$(state g owner)"

# The first one killed: its socket file stays behind, the next one takes it
pid_a="${PIDS[0]}"
kill -9 "$pid_a"
wait "$pid_a" 2>/dev/null
start h "$P"
check "after a killed owner: the next one owns the socket" 1 "$(state h owner)"
check "after a killed owner: same socket" "$sock" "$(state h socket)"

# Never a project's Neovim
skipped() {
    local name="$1"
    shift
    start "$name" "$P" "$@"
    state "$name" skipped
}
check "-R: skipped" flag "$(skipped r1 -R scripts/enemy/Enemy.cs)"
check "-d: skipped" flag "$(skipped r2 -d scripts/enemy/Enemy.cs project.godot)"
check "git's commit message: skipped" waiting "$(skipped r3 "$SB/work/repo/.git/COMMIT_EDITMSG")"
check "a temp file (\$TMPDIR): skipped" waiting "$(skipped r4 "$SB/tmpdir/zshAbc.zsh")"
check "a file in /var/tmp: skipped" waiting "$(skipped r5 /var/tmp/lyne-test-none.txt)"
check "a skipped Neovim leaves the owner alone" 1 "$(state h owner)"

# Headless without LYNE_NVIM_INSTANCE, and LYNE_NVIM_SOLO=1
(cd "$P" && exec env -u TMUX LYNE_NVIM_INSTANCE= "$SB/inst.sh" "$SB/s1.ctl") </dev/null >/dev/null 2>&1 &
PIDS+=($!)
_s1() { [[ "$(at s1 1)" == 1 ]]; }
wait_for 15 _s1 || fail_early "Neovim s1 didn't start"
check "headless: skipped" headless "$(state s1 skipped)"
(cd "$P" && exec env -u TMUX LYNE_NVIM_SOLO=1 "$SB/inst.sh" "$SB/s2.ctl") </dev/null >/dev/null 2>&1 &
PIDS+=($!)
_s2() { [[ "$(at s2 1)" == 1 ]]; }
wait_for 15 _s2 || fail_early "Neovim s2 didn't start"
check "LYNE_NVIM_SOLO=1: skipped" solo "$(state s2 skipped)"

# A real Neovim with its UI, in a tmux pane (no LYNE_NVIM_INSTANCE)
SOCK="$SB/tmux.sock"
mkdir -p "$SB/work/tui/.git"
env -u TMUX TMPDIR="$SB/tmpdir" tmux -S "$SOCK" -f /dev/null new-session -d -s t -x 120 -y 30 -c "$SB/work/tui" \
    "env -u LYNE_NVIM_SOLO -u LYNE_NVIM_INSTANCE $SB/nvim.sh"
PIDS+=("$(tmux -S "$SOCK" display -p -t t '#{pane_pid}')")
_tui() { [[ "$(nv 'luaeval("require(\"project_instance\").state.owner and 1 or 0")')" == 1 ]]; }
wait_for 15 _tui
check "with a UI in tmux: owns its project's socket" 1 "$(nv 'luaeval("require(\"project_instance\").state.owner and 1 or 0")')"
check "with a UI in tmux: its pane" "$(tmux -S "$SOCK" display -p -t t '#{pane_id}')" "$(nv 'luaeval("require(\"project_instance\").state.pane")')"
nv 'execute("qa!")' >/dev/null
tmux -S "$SOCK" kill-server 2>/dev/null

# Every tmux popup that runs Neovim sets LYNE_NVIM_SOLO=1
popups="$(grep -E '^bind .*display-popup.*nvim' "$REPO/tmux/.tmux.conf")"
check "tmux's Neovim popups found" 1 "$([[ -n "$popups" ]] && echo 1)"
check "every Neovim popup sets LYNE_NVIM_SOLO=1" "" "$(grep -v -- '-e LYNE_NVIM_SOLO=1' <<<"$popups")"

# The session name is config/projects.lua's
names='{"/a/game", "/a/.lyne-dots", "/a/my.app:v2", "/a/...", "/"}'
check "session names match config/projects.lua" 1 \
    "$(at h "luaeval('(function() for _, d in ipairs($names) do if require(\"project_instance\").session_name(d) ~= require(\"config.projects\").session_name(d) then return 0 end end return 1 end)()')")"

exit "$failed"
