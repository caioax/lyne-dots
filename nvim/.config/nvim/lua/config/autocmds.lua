-- TMUX INTEGRATION (Title Management)

-- Allow Neovim to change the terminal window title
vim.opt.title = true
vim.opt.titlelen = 0

local function set_window_title()
    -- Get the current file name and type
    local filename = vim.fn.expand("%:t")
    local filetype = vim.bo.filetype

    -- Logic for special buffers (not real files)
    if filename == "" or filetype == "snacks_dashboard" then
        if filetype == "neo-tree" then
            filename = "explorer"
        elseif filetype == "snacks_dashboard" then
            filename = "dashboard"
        elseif filetype == "TelescopePrompt" then
            filename = "telescope"
        else
            filename = "nvim"
        end
    end

    -- Apply the title
    vim.opt.titlestring = filename
end

-- Triggers: Update the title when entering a buffer, switching windows or gaining focus
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FocusGained", "VimResume" }, {
    group = vim.api.nvim_create_augroup("tmux_window_title", { clear = true }),
    callback = set_window_title,
})

-- VISUAL FEEDBACK (UX)

-- Highlight on Yank: Flash the text when copied (y)
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Flash text on yank",
    group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch", -- Highlight color (IncSearch inverts colors for high contrast)
            timeout = 150, -- Effect duration in milliseconds
        })
    end,
})
