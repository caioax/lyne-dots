return {
    "smart-splits-nvim/smart-splits.nvim",
    -- Never lazy: the tmux backend tells tmux this pane runs Neovim (the
    -- @pane-is-vim option tmux.conf's Ctrl/Alt + h/j/k/l read) when it loads
    lazy = false,
    dependencies = {
        -- Since v3 the multiplexers are plugins of their own
        { "smart-splits-nvim/backend-tmux", main = "smart-splits-backend-tmux" },
    },
    keys = {
        -- === NAVIGATION (Ctrl + h/j/k/l) ===
        {
            "<C-h>",
            function()
                require("smart-splits").move_cursor_left()
            end,
            desc = "Move focus to the left",
        },
        {
            "<C-j>",
            function()
                require("smart-splits").move_cursor_down()
            end,
            desc = "Move focus down",
        },
        {
            "<C-k>",
            function()
                require("smart-splits").move_cursor_up()
            end,
            desc = "Move focus up",
        },
        {
            "<C-l>",
            function()
                require("smart-splits").move_cursor_right()
            end,
            desc = "Move focus to the right",
        },

        -- === RESIZING (Alt + h/j/k/l) ===
        {
            "<A-h>",
            function()
                require("smart-splits").resize_left()
            end,
            desc = "Resize window to the left",
        },
        {
            "<A-j>",
            function()
                require("smart-splits").resize_down()
            end,
            desc = "Resize window down",
        },
        {
            "<A-k>",
            function()
                require("smart-splits").resize_up()
            end,
            desc = "Resize window up",
        },
        {
            "<A-l>",
            function()
                require("smart-splits").resize_right()
            end,
            desc = "Resize window to the right",
        },
    },
    config = function()
        require("smart-splits").setup({
            -- Inside tmux: past the last split, move to tmux's panes. Outside
            -- it the keys just move between Neovim's splits, without a warning
            mux = { backend = "smart-splits-backend-tmux", warn_if_unusable = false },
            -- Ignore buffers that should not be resized or navigated
            ignored_filetypes = {
                "nofile",
                "quickfix",
                "prompt",
            },
            ignored_buftypes = { "nofile" },
        })
    end,
}
