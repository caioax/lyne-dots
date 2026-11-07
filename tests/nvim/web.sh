#!/usr/bin/env bash
# Web pages in Neovim: a small site (index.html linking /style.css) is
# opened in the sandbox's headless Neovim. Emmet's server starts on the page
# and expands ul>li*2, typing <div> closes the tag (nvim-ts-autotag), and
# <leader>up from the CSS file with no page open previews the folder's
# index.html: the server serves the page and /style.css from the folder
# Neovim was opened in, and the same key stops it. The browser is a command
# that does nothing and the port a free one, so nothing opens.
#
# Usage: tests/nvim/web.sh   (needs nvim, curl, the plugins and Mason's
# emmet-language-server)
#   LYNE_TEST_NVIM=<dir>     another copy of nvim/.config/nvim (lib.sh)

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need_tools nvim curl
[[ -x "$NVIM_DATA/mason/bin/emmet-language-server" ]] || fail_early "no emmet-language-server in Mason (open nvim once)"

nvim_sandbox
NVIM_PID=""

cleanup() {
    [[ -n "$NVIM_PID" ]] && kill "$NVIM_PID" 2>/dev/null
    remove_sandbox "$NVIM_PID"
}
trap cleanup EXIT

site="$SB/site"
mkdir "$site"
cat >"$site/index.html" <<'EOF'
<!doctype html>
<link rel="stylesheet" href="/style.css">
<body>
</body>
EOF
echo 'body { color: red; }' >"$site/style.css"

(cd "$site" && exec "$SB/nvim.sh" --headless index.html) >/dev/null 2>&1 &
NVIM_PID=$!
wait_for 15 test -S "$SB/nvim.sock" || fail_early "Neovim didn't start"

lua() { nv "luaeval('$1')"; }

started() { [[ "$(lua '#vim.lsp.get_clients({ bufnr = 0, name = "emmet_language_server" })')" == 1 ]]; }
wait_for 20 started || fail_early "Emmet's server didn't start on the page"

# Emmet: the abbreviation on its own line inside body, then a completion
# request at its end (after the change reaches the server)
lua 'vim.api.nvim_buf_set_lines(0, 3, 3, false, { "ul>li*2" })' >/dev/null
sleep 1
expanded="$(lua '(function() local c = vim.lsp.get_clients({ bufnr = 0, name = "emmet_language_server" })[1]; local res = c:request_sync("textDocument/completion", { textDocument = { uri = vim.uri_from_bufnr(0) }, position = { line = 3, character = 7 } }, 5000, 0); local items = res and res.result and (res.result.items or res.result) or {}; local it = items[1]; return it and ((it.textEdit and it.textEdit.newText) or it.insertText or it.label):gsub("%s", "") or "" end)()')"
check "Emmet expands ul>li*2" '<ul><li>${1}</li><li>${0}</li></ul>' "$expanded"

# nvim-ts-autotag: typing <div> on a new line writes </div> after it
lua 'vim.api.nvim_buf_set_lines(0, 3, 4, false, {})' >/dev/null
lua 'vim.api.nvim_win_set_cursor(0, { 3, 0 })' >/dev/null
lua 'vim.api.nvim_feedkeys(vim.keycode("o<div><Esc>"), "xt", false)' >/dev/null
check "typing <div> closes the tag" "<div></div>" "$(lua 'vim.trim(vim.api.nvim_get_current_line())')"

# The preview from the CSS file, the page closed: the folder's index.html
port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
lua 'vim.cmd("bwipeout! index.html | edit style.css")' >/dev/null
lua "(function() local c = require(\"livepreview.config\").config; c.browser = \"true\"; c.port = $port end)()" >/dev/null
toggle='vim.fn.maparg(" up", "n", false, true).callback()'
lua "$toggle" >/dev/null
serving() { curl -sf "http://127.0.0.1:$port/" >/dev/null; }
wait_for 5 serving
check "<leader>up starts the preview" "true" "$(lua 'require("livepreview").is_running()')"
check "the page is served" 1 "$(curl -s "http://127.0.0.1:$port/" | grep -c 'stylesheet')"
check "/style.css is the folder's style.css" "body { color: red; }" "$(curl -s "http://127.0.0.1:$port/style.css" | tr -d '\n')"
lua "$toggle" >/dev/null
check "<leader>up again stops it" "false" "$(lua 'require("livepreview").is_running()')"

exit "$failed"
