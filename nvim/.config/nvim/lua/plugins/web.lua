-- Web pages (HTML, CSS, JS): a live preview in the browser and tags that
-- close and rename themselves. Emmet's abbreviations (ul>li*3) come from its
-- language server in lsp.lua

-- <leader>up: the preview of the file being edited, or of an open page when
-- it is a CSS or JS file, or of the project's index.html when no page is
-- open. The server serves the folder Neovim was opened in, so /style.css
-- means that folder's style.css, as it would on a real site
local function toggle_preview()
    local lp = require("livepreview")
    if lp.is_running() then
        lp.close()
        return
    end
    local utils = require("livepreview.utils")
    local index = vim.fs.joinpath(vim.uv.cwd(), "index.html")
    if
        not utils.supported_filetype(vim.api.nvim_buf_get_name(0))
        and not utils.find_supported_buf()
        and vim.uv.fs_stat(index)
    then
        vim.cmd.LivePreview({ args = { "start", index } })
    else
        vim.cmd.LivePreview("start")
    end
end

return {
    {
        "brianhuster/live-preview.nvim",
        cmd = { "LivePreview" },
        keys = {
            { "<leader>up", toggle_preview, desc = "Browser preview (toggle)" },
        },
    },
    {
        "windwp/nvim-ts-autotag",
        event = { "BufReadPre", "BufNewFile" },
        opts = {},
    },
}
