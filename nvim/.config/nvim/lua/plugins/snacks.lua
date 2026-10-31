-- Inside a terminal split (it takes the typing) the split keys work as
-- everywhere else (smart-splits.nvim): Ctrl+h/j/k/l move to the split on that
-- side, then tmux's panes; Alt+h/j/k/l resize. A floating one (lazygit) keeps
-- the keys for its program
local terminal_keys = {}
for _, k in ipairs({
    { "h", "left", "Focus the split on the left", "Grow or shrink the split to the left" },
    { "j", "down", "Focus the split below", "Grow or shrink the split downwards" },
    { "k", "up", "Focus the split above", "Grow or shrink the split upwards" },
    { "l", "right", "Focus the split on the right", "Grow or shrink the split to the right" },
}) do
    for _, kind in ipairs({ { "C", "move_cursor_", k[3], "nav_" }, { "M", "resize_", k[4], "resize_" } }) do
        local key = "<" .. kind[1] .. "-" .. k[1] .. ">"
        terminal_keys[kind[4] .. k[1]] = {
            key,
            function(self)
                if self:is_floating() then
                    return key
                end
                vim.schedule(function()
                    require("smart-splits")[kind[2] .. k[2]]()
                end)
            end,
            desc = kind[3],
            expr = true,
            mode = "t",
        }
    end
end

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
        terminal = {
            enabled = true,
            win = { keys = terminal_keys },
        },

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
        -- Also from inside it (terminal mode) to hide it again. Terminals send
        -- Ctrl+/ as Ctrl+_ (the same byte, 0x1f): that's the key Neovim gets
        {
            "<c-/>",
            function()
                Snacks.terminal()
            end,
            mode = { "n", "t" },
            desc = "Toggle Terminal",
        },
        {
            "<c-_>",
            function()
                Snacks.terminal()
            end,
            mode = { "n", "t" },
            desc = "Toggle Terminal (Ctrl+/ as terminals send it)",
        },
    },
}
