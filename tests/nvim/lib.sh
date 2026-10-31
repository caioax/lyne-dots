#!/usr/bin/env bash
# Shared by the tests/nvim scripts: output, checks and Neovim's sandbox.
#
# Isolation: Neovim's state and cache (shada, sessions, logs) go to a temp
# folder; its data folder is a link to yours, for the plugins lazy.nvim and
# Mason installed (nothing new is installed as long as those are there).
#   LYNE_TEST_NVIM=<dir>   another copy of nvim/.config/nvim

# shellcheck disable=SC2034  # REPO, C_* and SB are read by the scripts

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NVIM_DIR="${LYNE_TEST_NVIM:-$REPO/nvim/.config/nvim}"
NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

if [[ -t 1 ]]; then
    C_OK=$'\e[32m' C_FAIL=$'\e[31m' C_OFF=$'\e[0m'
else
    C_OK="" C_FAIL="" C_OFF=""
fi

fail_early() {
    printf '%s%s%s\n' "$C_FAIL" "$1" "$C_OFF"
    exit 1
}

# need_tools TOOL...: and the plugins lazy.nvim installed
need_tools() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null || fail_early "missing $tool"
    done
    [[ -d "$NVIM_DATA/lazy/lazy.nvim" ]] || fail_early "no plugins in $NVIM_DATA/lazy (open nvim once so lazy.nvim installs them)"
}

failed=0
check() {
    local name="$1" want="$2" got="$3"
    if [[ "$got" == "$want" ]]; then
        printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$name"
    else
        printf '%s✗ %s%s (want %s, got %s)\n' "$C_FAIL" "$name" "$C_OFF" "$want" "${got:-nothing}"
        failed=1
    fi
}

# wait_for SECONDS COMMAND...: until the command succeeds
wait_for() {
    local tries=$(($1 * 10))
    shift
    while ((tries-- > 0)); do
        "$@" && return 0
        sleep 0.1
    done
    return 1
}

# A short temp folder ($SB; tmux's socket may live in it) with the config,
# data, state, cache and runtime folders (the projects' sockets go to
# $SB/run/lyne-nvim), and $SB/nvim.sh: Neovim in them, listening
# on $SB/nvim.sock (arguments are passed on)
nvim_sandbox() {
    SB="$(mktemp -d /tmp/lnv.XXXXXX)" || fail_early "no sandbox"
    mkdir -p "$SB/config" "$SB/data" "$SB/state" "$SB/cache"
    mkdir -m 700 "$SB/run"
    ln -s "$NVIM_DIR" "$SB/config/nvim"
    ln -s "$NVIM_DATA" "$SB/data/nvim"
    cat >"$SB/nvim.sh" <<EOF
#!/bin/sh
export XDG_CONFIG_HOME="$SB/config" XDG_DATA_HOME="$SB/data" XDG_STATE_HOME="$SB/state" XDG_CACHE_HOME="$SB/cache" XDG_RUNTIME_DIR="$SB/run"
exec nvim --listen "$SB/nvim.sock" "\$@"
EOF
    chmod +x "$SB/nvim.sh"
}

# nv EXPR: evaluated in the sandbox's Neovim
nv() { nvim --headless --server "$SB/nvim.sock" --remote-expr "$1" 2>/dev/null; }

# Waits for PID to end (Neovim writes its shada while it quits), then
# removes the sandbox
remove_sandbox() {
    local pid="$1" tries=50
    while [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && ((tries-- > 0)); do
        sleep 0.1
    done
    rm -rf "$SB"
}

# attach_client SESSION: a tmux client of the server at $SOCK in a pty (its
# output thrown away), like a terminal showing SESSION; keys typed through
# it (send-keys -c "$CLIENT" -K) go through tmux's key tables. Sets CLIENT
# (its name) and CLIENT_PID
attach_client() {
    [[ -f "$SB/client.py" ]] || cat >"$SB/client.py" <<'EOF'
import fcntl, os, pty, select, struct, sys, termios
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.environ.pop("TMUX", None)
    os.execvp("tmux", ["tmux", "-S", sys.argv[1], "attach", "-t", sys.argv[2]])
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
    python3 "$SB/client.py" "$SOCK" "$1" &
    CLIENT_PID=$!
    # shellcheck disable=SC2329  # called by wait_for
    _attached() { [[ -n "$(tmux -S "$SOCK" list-clients -F '#{client_name}' 2>/dev/null)" ]]; }
    wait_for 5 _attached || fail_early "no tmux client"
    CLIENT="$(tmux -S "$SOCK" list-clients -F '#{client_name}' | head -1)"
}
