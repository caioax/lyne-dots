-- Neovim started in a tmux popup to show one Telescope list (the shortcut
-- search, the projects): the list opens once the UI is up and quits Neovim,
-- and with it the popup, when it closes

local M = {}

-- Runs `open` now, or, while `nvim -c` is still starting, once the UI is up:
-- the dashboard decides on UIEnter whether to open over the first buffer
-- (when the current one has no name) and would take the focus from the
-- list. The list opens after it, over a named scratch buffer the dashboard
-- leaves be
function M.start(open)
    if vim.v.vim_did_enter == 1 then
        open()
        return
    end
    vim.bo.buftype = "nofile"
    vim.api.nvim_buf_set_name(0, "popup")
    vim.api.nvim_create_autocmd("UIEnter", {
        once = true,
        callback = vim.schedule_wrap(open),
    })
end

-- In a picker's attach_mappings: closing it quits Neovim
function M.quit_on_close(actions)
    actions.close:enhance({
        post = function()
            vim.cmd("qa!")
        end,
    })
end

return M
