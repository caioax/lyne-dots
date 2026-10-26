return {
    "folke/snacks.nvim",
    dependencies = { "echasnovski/mini.icons" },
    priority = 1000,
    lazy = false,
    opts = {
        -- === ENABLED MODULES ===
        bigfile = { enabled = true },
        indent = { enabled = true },
        input = { enabled = true },
        notifier = { enabled = true },
        quickfile = { enabled = true },
        scroll = { enabled = false },
        statuscolumn = { enabled = true },
        words = { enabled = true },
        lazygit = { enabled = true },
        scratch = { enabled = true },
        terminal = { enabled = true },

        -- DASHBOARD CONFIGURATION
        dashboard = {
            enabled = true,
            preset = {
                header = [[
                                                                     
       ████ ██████           █████      ██                     
      ███████████             █████                             
      █████████ ███████████████████ ███   ███████████   
     █████████  ███    █████████████ █████ ██████████████   
    █████████ ██████████ █████████ █████ █████ ████ █████   
  ███████████ ███    ███ █████████ █████ █████ ████ █████  
 ██████  █████████████████████ ████ █████ █████ ████ ██████ 
                ]],

                -- Menu Buttons
                keys = {
                    {
                        icon = " ",
                        key = "f",
                        desc = "Find File",
                        action = function()
                            require("telescope.builtin").find_files()
                        end,
                    },
                    {
                        icon = " ",
                        key = "n",
                        desc = "New File",
                        action = ":ene | startinsert",
                    },
                    {
                        icon = " ",
                        key = "g",
                        desc = "Find Text",
                        action = function()
                            require("telescope.builtin").live_grep()
                        end,
                    },
                    {
                        icon = " ",
                        key = "r",
                        desc = "Recent Files",
                        action = function()
                            require("telescope.builtin").oldfiles()
                        end,
                    },
                    {
                        icon = " ",
                        key = "c",
                        desc = "Configuration",
                        action = function()
                            require("telescope.builtin").find_files({
                                cwd = vim.fn.stdpath("config"),
                                prompt_title = " Neovim Config Files",
                                follow = true,
                            })
                        end,
                    },
                    {
                        icon = " ",
                        key = "s",
                        desc = "Restore Session",
                        section = "session",
                    },
                    {
                        icon = " ",
                        key = "q",
                        desc = "Quit",
                        action = ":qa",
                    },
                },
            },
            sections = {
                { section = "header" },
                { section = "keys", gap = 1, padding = 1 },
                {
                    {
                        function()
                            -- 1. Lazy data (Plugins and Time)
                            local stats = require("lazy").stats()
                            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)

                            -- 2. Neovim Version data
                            local v = vim.version()
                            local version = "v" .. v.major .. "." .. v.minor .. "." .. v.patch

                            -- 3. Current Date
                            local date = os.date("%d/%m - %H:%M")

                            -- 4. Update Check
                            -- Need to require lazy status
                            local plugin_updates = ""
                            local lazy_status = require("lazy.status")
                            if lazy_status.has_updates() then
                                plugin_updates = "  󰮯 " .. lazy_status.updates() .. " updates"
                            end

                            return {
                                align = "center",
                                text = {
                                    -- Line 1: Version and Date
                                    { "  ", hl = "SnacksDashboardIcon" }, -- Blue Icon
                                    { version, hl = "SnacksDashboardKey" }, -- Yellow Version
                                    { "     ", hl = "SnacksDashboardIcon" },
                                    { date, hl = "SnacksDashboardDesc" }, -- White Date
                                    { "\n\n", hl = "Normal" }, -- Line break

                                    -- Line 2: Performance and Plugins
                                    { "Neovim loaded ", hl = "SnacksDashboardDesc" },
                                    { stats.loaded .. "/" .. stats.count, hl = "SnacksDashboardKey" },
                                    { " plugins in ", hl = "SnacksDashboardDesc" },
                                    { ms .. "ms", hl = "SnacksDashboardSpecial" },

                                    -- Line 3 (Only appears if there are updates)
                                    { plugin_updates, hl = "DiagnosticError" }, -- Red if there are updates
                                },
                            }
                        end,
                    },
                },
            },
        },
    },

    -- (Global Shortcuts) --
    keys = {
        {
            "<leader>sf",
            function()
                Snacks.scratch()
            end,
            desc = "Toggle Scratch Buffer",
        },
        {
            "<leader>S",
            function()
                Snacks.scratch.select()
            end,
            desc = "Select Scratch Buffer",
        },
        {
            "<leader>gl",
            function()
                Snacks.lazygit.log_file()
            end,
            desc = "Lazygit Log (cwd)",
        },
        {
            "<leader>lg",
            function()
                Snacks.lazygit()
            end,
            desc = "Lazygit",
        },
        {
            "<leader>un",
            function()
                Snacks.notifier.hide()
            end,
            desc = "Dismiss All Notifications",
        },
        {
            "<c-/>",
            function()
                Snacks.terminal()
            end,
            desc = "Toggle Terminal",
        },
    },
}
