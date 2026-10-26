return {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    keys = {
        { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
        { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Find Text" },
        { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Open Buffers" },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                path_display = { "tail" }, -- Show only the file name, hide the long path
                -- Lua patterns on the path: anchored to whole folder names, so
                -- git.lua, .github and .gitignore still show
                file_ignore_patterns = { "^%.git/", "/%.git/", "^node_modules/", "/node_modules/" },

                -- === Side preview configuration ===
                sorting_strategy = "ascending", -- Make the list start from the top
                layout_strategy = "horizontal", -- Ensure side-by-side layout
                layout_config = {
                    horizontal = {
                        prompt_position = "top", -- Search bar at the top
                        preview_width = 0.6, -- Preview takes 60% of the width
                    },
                    width = 0.85,
                    height = 0.85,
                },
            },
            pickers = {
                -- Hidden files too (.github, .data...); what .gitignore lists
                -- stays out
                find_files = { hidden = true },
            },
        })
    end,
}
