-- Keys only some buffers get: the ones with an LSP server (lsp.lua's
-- LspAttach) and the ones under git (gitsigns' on_attach). Kept here as data
-- so the shortcut search (config.shortcuts) lists them in any buffer.
-- Each entry: { mode, lhs, rhs, desc, expr = bool }

local M = {}

M.lsp = {
    {
        "n",
        "gl",
        function()
            vim.diagnostic.open_float({
                scope = "line",
                border = "rounded",
                source = true,
                header = "",
                prefix = "",
            })
        end,
        "View Line Error (Float)",
    },
    {
        "n",
        "gd",
        function()
            require("telescope.builtin").lsp_definitions()
        end,
        "Go to Definition",
    },
    -- grr is Neovim's own key for references (with grn rename, gra code
    -- action, gri implementation): in Telescope here
    {
        "n",
        "grr",
        function()
            require("telescope.builtin").lsp_references()
        end,
        "Go to References",
    },
    {
        "n",
        "K",
        function()
            vim.lsp.buf.hover()
        end,
        "Hover Documentation",
    },
    {
        "n",
        "<leader>rn",
        function()
            vim.lsp.buf.rename()
        end,
        "Rename Variable",
    },
    {
        "n",
        "<leader>ca",
        function()
            vim.lsp.buf.code_action()
        end,
        "Code Action",
    },
    -- Quick navigation between errors: [d and ]d are Neovim's own
}

-- ]c / [c: Vim's own in diff mode, gitsigns' changes otherwise
local function hunk(direction, key)
    return function()
        if vim.wo.diff then
            return key
        end
        vim.schedule(function()
            require("gitsigns").nav_hunk(direction)
        end)
        return "<Ignore>"
    end
end

M.git = {
    { "n", "]c", hunk("next", "]c"), "Next git change", expr = true },
    { "n", "[c", hunk("prev", "[c"), "Previous git change", expr = true },
    {
        "n",
        "<leader>gb",
        function()
            require("gitsigns").toggle_current_line_blame()
        end,
        "Git Blame (Line)",
    },
    {
        "n",
        "<leader>gd",
        function()
            require("gitsigns").diffthis()
        end,
        "Git Diff",
    },
    {
        "n",
        "<leader>gp",
        function()
            require("gitsigns").preview_hunk()
        end,
        "Preview Change",
    },
}

-- Where each list's keys come from, shown in the search; the LSP ones also
-- carry it in their desc
M.labels = { lsp = "LSP", git = "Git" }

-- Sets the keys of `list` ("lsp" or "git") in buffer `buf`
function M.apply(list, buf)
    local prefix = list == "lsp" and "LSP: " or ""
    for _, k in ipairs(M[list]) do
        vim.keymap.set(k[1], k[2], k[3], { buffer = buf, desc = prefix .. k[4], expr = k.expr })
    end
end

return M
