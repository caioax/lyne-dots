#!/usr/bin/env bash
# Neovim's config working with what Neovim and the plugins expect today: a Lua
# file with a diagnostic and a git change is opened in the sandbox of lib.sh,
# the LSP starts, and the keys that call into Neovim and the plugins are used
# (yank, ]d / [d, ]c / [c, format, <leader>ff). lua_ls must know vim
# (lazydev.nvim), conform's stylua follows a project's stylua.toml and
# .styluaignore (4 spaces outside any), and the repo's Lua is formatted. Then nothing deprecated may have been
# called (:checkhealth vim.deprecated), the servers get nvim-cmp's
# capabilities, stylua runs only as conform's formatter, grr is the
# references key, and every map has a desc (no_desc.lua).
#
# Usage: tests/nvim/config.sh   (needs nvim, git, the plugins and Mason's
# lua-language-server and stylua)
#   CONFIG_DEBUG=1           print the health report and :messages
#   LYNE_TEST_NVIM=<dir>     another copy of nvim/.config/nvim (lib.sh)

# shellcheck disable=SC2329  # cleanup runs from the trap, the others from wait_for

set -uo pipefail

# shellcheck source=tests/nvim/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_tools nvim git
[[ -x "$NVIM_DATA/mason/bin/lua-language-server" ]] || fail_early "no lua-language-server in Mason (open a Lua file in nvim once)"
[[ -x "$NVIM_DATA/mason/bin/stylua" ]] || fail_early "no stylua in Mason (open nvim once)"

nvim_sandbox
NVIM_PID=""

cleanup() {
    [[ -n "$NVIM_PID" ]] && kill "$NVIM_PID" 2>/dev/null
    remove_sandbox "$NVIM_PID"
}
trap cleanup EXIT

# A git repo with one committed file, then changed: line 3 has a diagnostic
# (undefined global; vim on it is known, lazydev.nvim), line 5 a git hunk
mkdir "$SB/work"
cat >"$SB/work/t.lua" <<'EOF'
local M = {}
function M.value()
    return undefined_value or vim.fn.getcwd()
end
return M
EOF
# For <leader>ff: names with "git" in them, hidden folders, and what it must
# leave out (.git/, node_modules/, what .gitignore lists)
mkdir -p "$SB/work/lua/plugins" "$SB/work/.github/workflows" "$SB/work/.data" "$SB/work/node_modules/m"
for f in lua/plugins/git.lua .github/workflows/ci.yml .data/state node_modules/m/i.js ignored.txt; do
    echo x >"$SB/work/$f"
done
echo ignored.txt >"$SB/work/.gitignore"
# For conform's stylua (in fmt/, which .gitignore keeps out of <leader>ff):
# Lua outside any stylua.toml (tabs), inside a project whose stylua.toml
# wants tabs (4 spaces), and a file its .styluaignore lists
mkdir -p "$SB/work/fmt/style"
echo fmt/ >>"$SB/work/.gitignore"
printf 'local t = {\n\tx = 1,\n}\nreturn t\n' >"$SB/work/fmt/loose.lua"
printf 'indent_type = "Tabs"\n' >"$SB/work/fmt/style/.stylua.toml"
printf 'local t = {\n    x = 1,\n}\nreturn t\n' >"$SB/work/fmt/style/own.lua"
echo aligned.lua >"$SB/work/fmt/style/.styluaignore"
printf 'local t = {\n    x   = 1,\n}\nreturn t\n' >"$SB/work/fmt/style/aligned.lua"
git -C "$SB/work" init -q
git -C "$SB/work" add t.lua
git -C "$SB/work" -c user.name=test -c user.email=test@example.com commit -qm test
sed -i 's/^return M$/return M -- changed/' "$SB/work/t.lua"

(cd "$SB/work" && exec "$SB/nvim.sh" --headless t.lua) >/dev/null 2>&1 &
NVIM_PID=$!

lua() { nv "luaeval('$1')"; }
keys() {
    nvim --headless --server "$SB/nvim.sock" --remote-send "$1" 2>/dev/null
    sleep 0.4
}
row() { nv 'line(".")'; }

started() { [[ -S "$SB/nvim.sock" ]] && [[ "$(lua '#vim.lsp.get_clients({ bufnr = 0, name = "lua_ls" })')" == 1 ]]; }
wait_for 40 started || fail_early "lua_ls didn't start"
diagnosed() { [[ "$(lua '#vim.diagnostic.get(0)')" -gt 0 ]]; }
wait_for 30 diagnosed || fail_early "lua_ls reported nothing on the test file"
signed() { [[ "$(lua 'vim.b.gitsigns_status_dict and 1 or 0')" == 1 ]]; }
wait_for 15 signed || fail_early "gitsigns didn't attach"

# lazydev.nvim hands lua_ls Neovim's types once the file is open
vim_known() { [[ "$(lua '#vim.tbl_filter(function(d) return d.message:find("vim", 1, true) end, vim.diagnostic.get(0))')" == 0 ]]; }
wait_for 15 vim_known
check "lua_ls knows vim (lazydev.nvim), the undefined global is still reported" "0 1" \
    "$(lua '#vim.tbl_filter(function(d) return d.message:find("vim", 1, true) end, vim.diagnostic.get(0)) .. " " .. #vim.tbl_filter(function(d) return d.message:find("undefined_value", 1, true) end, vim.diagnostic.get(0))')"
check "diagnostics show their message at the end of the line" 1 "$(lua 'vim.diagnostic.config().virtual_text and 1 or 0')"
check "lua_ls gets nvim-cmp's capabilities (preselect)" 1 \
    "$(lua 'vim.tbl_get(vim.lsp.get_clients({ name = "lua_ls" })[1].capabilities, "textDocument", "completion", "completionItem", "preselectSupport") and 1 or 0')"
check "stylua doesn't run as a server" 0 "$(lua '#vim.lsp.get_clients({ name = "stylua" })')"
missing="$(nv "luaeval('dofile(_A)', '$REPO_TESTS/no_desc.lua')")"
check "every map of the config has a desc (which-key, shortcut search)" "" "$missing"
check "grr opens the references" "LSP: Go to References" "$(nv 'maparg("grr", "n", 0, 1).desc')"
check "no gr map waiting in front of grn/grr/gra/gri" 0 \
    "$(lua '#vim.tbl_filter(function(m) return m.lhs == "gr" end, vim.api.nvim_buf_get_keymap(0, "n"))')"

keys 'yy'
keys 'gg]d'
check "]d jumps to the diagnostic" 3 "$(row)"
keys 'G[d'
check "[d jumps back to it" 3 "$(row)"
keys 'gg]c'
check "]c jumps to the git change" 5 "$(row)"
keys 'gg[c'
check "[c wraps around to it" 5 "$(row)"
keys '<Space>mp'
sleep 1
keys 'Go(<Esc>'
check "typing ( closes it (autopairs, loaded on insert)" "()" "$(nv 'getline(".")')"

nv 'execute("checkhealth vim.deprecated")' >/dev/null
health="$(nv 'join(getline(1, "$"), "\n")')"
messages="$(nv 'execute("messages")')"
if [[ -n "${CONFIG_DEBUG:-}" ]]; then
    printf '%s\n\nMESSAGES:%s\n' "$health" "$messages"
fi
check "checkhealth vim.deprecated: OK" 1 "$(grep -c 'No deprecated functions detected' <<<"$health")"
grep 'WARNING' <<<"$health" | sed 's/^/    /'
check "no message about something deprecated" 0 "$(grep -ci 'deprecated' <<<"$messages")"

# formatted FILE: its line 2 after conform formats it (what a save does)
formatted() {
    nv "execute('edit $SB/work/$1')" >/dev/null
    lua 'require("conform").format({ async = false })' >/dev/null
    nv 'getline(2)'
}
check "stylua: Lua outside any stylua.toml gets 4 spaces" "    x = 1," "$(formatted fmt/loose.lua)"
check "stylua: a project's stylua.toml wins (tabs here)" $'\tx = 1,' "$(formatted fmt/style/own.lua)"
check "stylua: what .styluaignore lists stays as it is" "    x   = 1," "$(formatted fmt/style/aligned.lua)"
nv "execute('edit $SB/work/t.lua')" >/dev/null

keys '<Space>ff'
sleep 1
found="$(lua '(function() local p = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf()); local r = {}; for e in p.manager:iter() do r[#r + 1] = e.value end; table.sort(r); return table.concat(r, " ") end)()')"
check "<leader>ff finds hidden files and names with git, not .git/ nor ignored ones" \
    ".data/state .github/workflows/ci.yml .gitignore lua/plugins/git.lua t.lua" "$found"
keys '<Esc><Esc>'

# Deprecated in the plugins without vim.deprecate (so no health warning):
# gitsigns' next_hunk/prev_hunk, conform's lsp_fallback; and Neovim's own
# that only warn when called
old="$(grep -rnE 'vim\.loop\.|vim\.highlight\.|diagnostic\.goto_(next|prev)|\.(next|prev)_hunk\(|lsp_fallback|require\("lspconfig"\)\[' "$NVIM_DIR/lua" "$NVIM_DIR/init.lua")"
check "no deprecated names left in the config" "" "$old"

# The repo's Lua is as stylua leaves it (.stylua.toml, Hyprland's left out
# by .styluaignore): saving a file rewrites nothing
unformatted="$(cd "$REPO" && git ls-files '*.lua' | xargs "$NVIM_DATA/mason/bin/stylua" --respect-ignores --check 2>&1 | grep '^Diff in')"
check "the repo's Lua is formatted (stylua --check)" "" "$unformatted"

exit "$failed"
