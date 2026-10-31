-- The open files as tabs on top: one Neovim per project keeps them all, so
-- they are a Shift+H / Shift+L away instead of a trip through the tree.
-- Shown once there are two (the dashboard and a single file need none)
return {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
        { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous open file (tab)" },
        { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next open file (tab)" },
        { "<leader>bb", "<cmd>BufferLinePick<cr>", desc = "Pick an open file by its letter" },
        { "<leader>bh", "<cmd>BufferLineMovePrev<cr>", desc = "Move the tab to the left" },
        { "<leader>bl", "<cmd>BufferLineMoveNext<cr>", desc = "Move the tab to the right" },
        {
            "<leader>bd",
            function()
                Snacks.bufdelete()
            end,
            desc = "Close the file (its splits stay)",
        },
        {
            "<leader>bo",
            function()
                Snacks.bufdelete.other()
            end,
            desc = "Close the other files",
        },
    },
    opts = {
        options = {
            -- Closing from a tab keeps the window layout, as <leader>bd does
            close_command = function(buf)
                Snacks.bufdelete(buf)
            end,
            right_mouse_command = function(buf)
                Snacks.bufdelete(buf)
            end,
            diagnostics = "nvim_lsp",
            always_show_bufferline = false,
            -- The file tree keeps its column; the tabs start after it
            offsets = {
                { filetype = "neo-tree", text = "Files", highlight = "Directory", text_align = "left" },
            },
        },
    },
    config = function(_, opts)
        require("bufferline").setup(opts)
        -- Files restored by a session (persistence.nvim) show up at once
        vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "SessionLoadPost" }, {
            group = vim.api.nvim_create_augroup("bufferline_refresh", { clear = true }),
            callback = function()
                vim.schedule(function()
                    pcall(require("bufferline").refresh)
                end)
            end,
        })
    end,
}
