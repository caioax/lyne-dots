#!/usr/bin/env bash
# QML in Neovim, the way Quickshell's configs need it: a small Quickshell
# config in the sandbox (a singleton in config/ imported as qs.config, no
# qmldir, like the shell's folders) gets its .qmlls.ini filled by a real
# Quickshell (qs -p, no windows), then a QML file of it is opened in the
# sandbox's headless Neovim: Treesitter highlights it with qmljs, qmlls
# starts in the config's folder and resolves qs.config (no import warning,
# a missing member of the singleton is reported). The shell's own folders
# must have no qmldir: Quickshell's qmlls support only sees the ones it
# writes.
#
# Usage: tests/nvim/qml.sh   (needs nvim, qs, qmlls6, the plugins and the
# qmljs parser, and a Wayland session for qs)
#   LYNE_TEST_NVIM=<dir>     another copy of nvim/.config/nvim (lib.sh)

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need_tools nvim qs qmlls6
[[ -n "${WAYLAND_DISPLAY:-}" ]] || fail_early "no Wayland session (qs fills .qmlls.ini when it runs)"

check "the shell's folders have no qmldir of their own" "" \
    "$(cd "$REPO/quickshell/.config/quickshell" && find . -name qmldir)"

nvim_sandbox
NVIM_PID=""
QS_PID=""
VFS=""

cleanup() {
    [[ -n "$QS_PID" ]] && kill "$QS_PID" 2>/dev/null
    [[ -n "$NVIM_PID" ]] && kill "$NVIM_PID" 2>/dev/null
    # Quickshell's generated folder for this config
    [[ "$VFS" == "${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell/vfs/"?* ]] && rm -rf "$VFS"
    remove_sandbox "$NVIM_PID"
}
trap cleanup EXIT

shell="$SB/shell"
mkdir -p "$shell/config"
cat >"$shell/config/Cfg.qml" <<'EOF'
pragma Singleton
import Quickshell

Singleton {
    property int size: 10
}
EOF
cat >"$shell/Widget.qml" <<'EOF'
import QtQuick
import qs.config

Item {
    width: Cfg.size
    height: Cfg.missingSize
}
EOF
cat >"$shell/shell.qml" <<'EOF'
import Quickshell

Scope {
    Widget {}
}
EOF
: >"$shell/.qmlls.ini"

qs -p "$shell/shell.qml" >"$SB/qs.log" 2>&1 &
QS_PID=$!
filled() { [[ -L "$shell/.qmlls.ini" ]] && grep -q buildDir "$shell/.qmlls.ini" 2>/dev/null; }
wait_for 15 filled || fail_early "Quickshell didn't fill .qmlls.ini (see $SB/qs.log)"
VFS="$(dirname "$(readlink "$shell/.qmlls.ini")")"
kill "$QS_PID" 2>/dev/null
QS_PID=""

(cd "$shell" && exec "$SB/nvim.sh" --headless Widget.qml) >/dev/null 2>&1 &
NVIM_PID=$!
wait_for 15 test -S "$SB/nvim.sock" || fail_early "Neovim didn't start"

lua() { nv "luaeval('$1')"; }
started() { [[ "$(lua '#vim.lsp.get_clients({ bufnr = 0, name = "qmlls" })')" == 1 ]]; }
wait_for 20 started || fail_early "qmlls didn't start"
diagnosed() { [[ "$(lua '#vim.diagnostic.get(0)')" -gt 0 ]]; }
wait_for 30 diagnosed
messages="$(lua 'table.concat(vim.tbl_map(function(d) return (d.lnum + 1) .. ": " .. d.message end, vim.diagnostic.get(0)), "\n")')"

check "the file is QML, highlighted by Treesitter's qmljs" "qml qmljs 1" \
    "$(lua 'vim.bo.filetype .. " " .. vim.treesitter.language.get_lang(vim.bo.filetype) .. " " .. (vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] and 1 or 0)')"
check "qmlls runs from the config's folder" "$shell" "$(lua 'vim.lsp.get_clients({ name = "qmlls" })[1].root_dir')"
check "qs.config is found (no import warning)" 0 "$(grep -c 'import' <<<"$messages")"
check "a missing member of the singleton is reported" 1 "$(grep -c '^6: .*missingSize' <<<"$messages")"

exit "$failed"
