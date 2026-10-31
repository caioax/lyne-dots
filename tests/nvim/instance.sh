#!/usr/bin/env bash
# One Neovim per project (local-plugins/project-instance.nvim): the first
# Neovim opened in a project listens on that project's socket in
# $XDG_RUNTIME_DIR/lyne-nvim (the sandbox's), found from the first file (the
# nearest folder with project.godot, a *.sln or .git, else the file's
# folder) or the current folder. One started there later hands its files
# (and a +N line) to the first and quits; in tmux the client lands on the
# first's pane, whatever window or session it was in, out of a floating
# window and back to normal mode. A socket left by a killed Neovim is taken
# over, and the Neovims that are never a project's (LYNE_NVIM_SOLO, no UI,
# -R/-d/stdin, git's files and temp files, $TMPDIR here) don't touch it. The
# session name matches config/projects.lua's.
#
# The Neovims run headless with LYNE_NVIM_INSTANCE=1 (headless ones are
# skipped otherwise); each one is driven through its own --listen socket.
#
# Usage: tests/nvim/instance.sh   (needs nvim and the plugins)
#   LYNE_TEST_NVIM=<dir>   another copy of nvim/.config/nvim (lib.sh)
#   LYNE_TEST_ZSHRC=<file> another copy of zsh/.zshrc (its tmux function)

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
touch "$P/project.godot" "$P/Game.sln" "$P/scripts/enemy/Enemy.txt" "$SB/work/sln/App.sln" "$SB/work/repo/src/x.lua"
touch "$SB/work/repo/.git/COMMIT_EDITMSG"
# Same folder name elsewhere: its own socket
mkdir -p "$SB/other/game" && touch "$SB/other/game/project.godot"

# A project from a file deep inside it, started from another folder
start a "$SB/work/plain" "$P/scripts/enemy/Enemy.txt"
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

# A second Neovim in the same project, outside tmux: its files and +N line go
# to the first, which says so, and it quits
printf 'l%s\n' 1 2 3 4 5 6 7 8 >"$P/scripts/Player.txt"
at a 'luaeval("(function() _G.notes = {} vim.notify = function(m) table.insert(_G.notes, m) end return 1 end)()")' >/dev/null
# launch NAME DIR ARGS...: like start, without waiting for it to answer
launch() {
    local name="$1" dir="$2"
    shift 2
    (cd "$dir" && exec env -u TMUX -u LYNE_NVIM_SOLO "$SB/inst.sh" "$SB/$name.ctl" "$@") </dev/null >/dev/null 2>&1 &
    LAST_PID=$!
    PIDS+=("$LAST_PID")
}
_gone() { ! kill -0 "$LAST_PID" 2>/dev/null; }
launch b "$P/scripts" Player.txt +6
check "second Neovim quits" 1 "$(wait_for 15 _gone && echo 1)"
check "its file opens in the first" "$P/scripts/Player.txt" "$(at a 'expand("%:p")')"
check "at its +N line" 6 "$(at a 'line(".")')"
check "the first says it came from another terminal" "Opened Player.txt from another terminal" "$(at a 'luaeval("_G.notes[#_G.notes]")')"
check "the socket still reaches the first" "%a" \
    "$(nvim --headless --server "$sock" --remote-expr 'luaeval("require(\"project_instance\").state.pane")' 2>/dev/null)"
launch b2 "$P/scripts"
check "no file: quits too" 1 "$(wait_for 15 _gone && echo 1)"
check "no file: the first keeps its file" "$P/scripts/Player.txt" "$(at a 'expand("%:p")')"
launch b3 "$P" "$P/scripts" "$P/project.godot" "$P/Game.sln"
check "folders left out, several files" 1 "$(wait_for 15 _gone && echo 1)"
check "several files: the first one shown" "$P/project.godot" "$(at a 'expand("%:p")')"
check "several files: the others listed" 1 "$(at a 'buflisted(bufnr("'"$P"'/Game.sln"))')"
check "no buffer for the folder" -1 "$(at a 'bufnr("^'"$P"'/scripts$")')"

# Other roots
start c "$SB/work/repo/src"
check "root: .git" "$SB/work/repo" "$(state c root)"
start d "$SB/work" "$SB/work/sln/New.txt"
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
# skipped NAME WANT DESC ARGS...: started here (not in a subshell, so its
# PID is kept for the cleanup), its skip reason checked
skipped() {
    local name="$1" want="$2" desc="$3"
    shift 3
    start "$name" "$P" "$@"
    check "$desc: skipped" "$want" "$(state "$name" skipped)"
}
skipped r1 flag "-R" -R scripts/enemy/Enemy.txt
skipped r2 flag "-d" -d scripts/enemy/Enemy.txt project.godot
skipped r3 waiting "git's commit message" "$SB/work/repo/.git/COMMIT_EDITMSG"
skipped r4 waiting "a temp file (\$TMPDIR)" "$SB/tmpdir/zshAbc.zsh"
skipped r5 waiting "a file in /var/tmp" /var/tmp/lyne-test-none.txt
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

# A real Neovim with its UI, in a tmux pane (no LYNE_NVIM_INSTANCE), seen
# through a client: one typed in another window of its session, or in
# another session, hands its files over and the client lands on its pane
SOCK="$SB/tmux.sock"
T() { tmux -S "$SOCK" "$@"; }
W="$SB/work/tui"
mkdir -p "$W/.git" "$W/sub"
printf 'l%s\n' 1 2 3 4 5 6 7 8 9 >"$W/f1.txt"
printf 'l%s\n' 1 2 3 4 5 6 7 8 9 >"$W/f2.txt"
# The Neovim typed in the panes: the sandbox's, without a --listen of its own
cat >"$SB/plain.sh" <<PLAIN
#!/bin/sh
export XDG_CONFIG_HOME="$SB/config" XDG_DATA_HOME="$SB/data" XDG_STATE_HOME="$SB/state" XDG_CACHE_HOME="$SB/cache" XDG_RUNTIME_DIR="$SB/run" TMPDIR="$SB/tmpdir"
unset LYNE_NVIM_SOLO LYNE_NVIM_INSTANCE
exec nvim "\$@"
PLAIN
chmod +x "$SB/plain.sh"
env -u TMUX TMPDIR="$SB/tmpdir" SHELL=/bin/sh tmux -S "$SOCK" -f /dev/null new-session -d -s t -x 120 -y 30 -c "$W" \
    "env -u LYNE_NVIM_SOLO -u LYNE_NVIM_INSTANCE $SB/nvim.sh f1.txt"
PIDS+=("$(T display -p -t t '#{pane_pid}')")
owner="$(T display -p -t t '#{pane_id}')"
_tui() { [[ "$(nv 'luaeval("require(\"project_instance\").state.owner and 1 or 0")')" == 1 ]]; }
wait_for 15 _tui
check "with a UI in tmux: owns its project's socket" 1 "$(nv 'luaeval("require(\"project_instance\").state.owner and 1 or 0")')"
check "with a UI in tmux: its pane" "$owner" "$(nv 'luaeval("require(\"project_instance\").state.pane")')"
other="$(T new-window -P -F '#{pane_id}' -t t: -c "$W" sh)"
far="$(T new-session -d -P -F '#{pane_id}' -s q -c "$W/sub" sh)"
# The client's pane: display -c only sets the client_* formats, a client as
# the target gives its current pane
client_pane() { T display -p -t "$CLIENT" '#{pane_id}'; }
attach_client t
T select-window -t "$other"
check "client on the other window before" "$other" "$(client_pane)"

# typed PANE ARGS...: a Neovim typed in PANE, until the pane's shell is back
typed() {
    local pane="$1"
    shift
    T send-keys -t "$pane" "$SB/plain.sh $*" Enter
    sleep 0.3
    _back() { [[ "$(T display -p -t "$pane" '#{pane_current_command}')" == sh ]]; }
    wait_for 15 _back
}

typed "$other" f2.txt +5
check "tmux: the typed Neovim quits" sh "$(T display -p -t "$other" '#{pane_current_command}')"
check "tmux: its file opens in the first" "$W/f2.txt" "$(nv 'expand("%:p")')"
check "tmux: at its +N line" 5 "$(nv 'line(".")')"
check "tmux: the client lands on the first's pane" "$owner" "$(client_pane)"

# The first one in insert mode with a floating window focused; the client in
# another session
T send-keys -t "$owner" i
nv 'luaeval("vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, { relative = \"editor\", row = 1, col = 1, width = 10, height = 3 }) and 1")' >/dev/null
check "float focused before" 1 "$(nv 'luaeval("vim.api.nvim_win_get_config(0).relative ~= \"\" and 1 or 0")')"
T switch-client -c "$CLIENT" -t q
check "client in the other session before" "$far" "$(client_pane)"
typed "$far" ../f1.txt
check "tmux: from another session, the client switches session" t "$(T display -p -c "$CLIENT" '#{client_session}')"
check "tmux: and lands on the first's pane" "$owner" "$(client_pane)"
check "tmux: the file opens in a normal window" "$W/f1.txt" "$(nv 'expand("%:p")')"
check "tmux: not in the floating window" 0 "$(nv 'luaeval("vim.api.nvim_win_get_config(0).relative ~= \"\" and 1 or 0")')"
check "tmux: back to normal mode" n "$(nv 'mode()')"

T switch-client -c "$CLIENT" -t q
check "client back in the other session" "$far" "$(client_pane)"
typed "$far"
check "tmux: no file, the client still goes to the first" "$owner" "$(client_pane)"

# The files handed over show as tabs on top (bufferline.nvim), Shift+L goes
# to the next one, <leader>| splits side by side
tabs() { T capture-pane -p -t "$owner" | head -1; }
_tabs() { [[ "$(tabs)" == *f1.txt* && "$(tabs)" == *f2.txt* ]]; }
wait_for 10 _tabs
check "tabs: both files on the top line" 1 "$(_tabs && echo 1)"
before="$(nv 'expand("%:t")')"
T send-keys -t "$owner" Escape L
sleep 0.5
check "tabs: Shift+L goes to the other file" 1 "$([[ "$(nv 'expand("%:t")')" != "$before" ]] && echo 1)"
T send-keys -t "$owner" Space '|'
sleep 0.5
check "<leader>| splits side by side" 2 "$(nv 'luaeval("#vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == \"\" end, vim.api.nvim_tabpage_list_wins(0))")')"
T send-keys -t "$owner" Space w q
sleep 0.5
check "<leader>wq closes the split" 1 "$(nv 'luaeval("#vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == \"\" end, vim.api.nvim_tabpage_list_wins(0))")')"

# Never handed over: -R stays open in its pane
T send-keys -t "$other" "$SB/plain.sh -R f2.txt" Enter
sleep 2
check "tmux: -R stays open" nvim "$(T display -p -t "$other" '#{pane_current_command}')"
T send-keys -t "$other" Escape ':qa!' Enter
nv 'execute("qa!")' >/dev/null
sleep 0.5
T kill-server 2>/dev/null
kill "$CLIENT_PID" 2>/dev/null

# Every tmux popup that runs Neovim sets LYNE_NVIM_SOLO=1
popups="$(grep -E '^bind .*display-popup.*nvim' "$REPO/tmux/.tmux.conf")"
check "tmux's Neovim popups found" 1 "$([[ -n "$popups" ]] && echo 1)"
check "every Neovim popup sets LYNE_NVIM_SOLO=1" "" "$(grep -v -- '-e LYNE_NVIM_SOLO=1' <<<"$popups")"

# The shell's tmux (zsh/.zshrc) with no arguments in a project: that
# project's session; anywhere else, with arguments or inside tmux, plain
# tmux. A stand-in tmux logs what it gets
ZSHRC="${LYNE_TEST_ZSHRC:-$REPO/zsh/.zshrc}"
tmux_fn="$(sed -n '/^tmux() {/,/^}/p' "$ZSHRC")"
check "zshrc has its tmux function" 1 "$([[ -n "$tmux_fn" ]] && echo 1)"
mkdir -p "$SB/fakebin"
printf '#!/bin/sh\necho "ARGS:$*" >>"%s"\n' "$SB/tmux-args.log" >"$SB/fakebin/tmux"
chmod +x "$SB/fakebin/tmux"
shell_tmux() {
    local dir="$1"
    shift
    : >"$SB/tmux-args.log"
    (cd "$dir" && env -u TMUX PATH="$SB/fakebin:$PATH" LYNE_DOTS="$REPO" XDG_RUNTIME_DIR="$SB/run" \
        TMPDIR="$SB/tmpdir" zsh -fc "$tmux_fn; tmux $*")
    cat "$SB/tmux-args.log"
}
check "tmux in a project's subfolder: its session" "ARGS:new-session -A -s game -c $P" "$(shell_tmux "$P/scripts")"
check "tmux outside any project: plain" "ARGS:" "$(shell_tmux "$SB/work/plain/sub")"
check "tmux with arguments: as given" "ARGS:ls" "$(shell_tmux "$P" ls)"
check "tmux inside tmux: as given" "ARGS:" "$(cd "$P" && : >"$SB/tmux-args.log" && env TMUX=x PATH="$SB/fakebin:$PATH" LYNE_DOTS="$REPO" zsh -fc "$tmux_fn; tmux" && cat "$SB/tmux-args.log")"

# The session name is config/projects.lua's
names='{"/a/game", "/a/.lyne-dots", "/a/my.app:v2", "/a/...", "/"}'
check "session names match config/projects.lua" 1 \
    "$(at h "luaeval('(function() for _, d in ipairs($names) do if require(\"project_instance\").session_name(d) ~= require(\"config.projects\").session_name(d) then return 0 end end return 1 end)()')")"

exit "$failed"
