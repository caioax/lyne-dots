local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Every map has a desc: which-key and the shortcut search (tmux prefix + ?)
-- show it
local function with(desc)
    return vim.tbl_extend("force", opts, { desc = desc })
end

-- Clear search highlight
map("n", "<Esc>", ":nohlsearch<CR>", with("Clear search highlight"))

-- --- EDITING ---
-- Move lines
map("v", "J", ":m '>+1<CR>gv=gv", with("Move selected lines down"))
map("v", "K", ":m '<-2<CR>gv=gv", with("Move selected lines up"))

-- --- SPLITS ---
-- The same keys as tmux's prefix + | and -; Ctrl/Alt + h/j/k/l move between
-- and resize them (smart-splits.nvim)
map("n", "<leader>|", "<cmd>vsplit<cr>", with("Split this window side by side"))
map("n", "<leader>-", "<cmd>split<cr>", with("Split this window top and bottom"))
map("n", "<leader>wq", "<cmd>close<cr>", with("Close the split"))
map("n", "<leader>wo", "<cmd>only<cr>", with("Close the other splits"))
map("n", "<leader>w=", "<C-w>=", with("Make the splits the same size"))

-- --- CLIPBOARD & REGISTERS ---

-- 1. SYSTEM (Top Priority)
-- Default behavior now interacts with the system Ctrl+C/V
map({ "n", "v" }, "y", [["+y]], { desc = "Copy (system clipboard)" })
map("n", "Y", [["+Y]], { desc = "Copy to the end of the line (system clipboard)" })
map({ "n", "v" }, "p", [["+p]], { desc = "Paste after (system clipboard)" }) -- replaces the selection in visual mode
map({ "n", "v" }, "P", [["+P]], { desc = "Paste before (system clipboard)" })

-- 2. INTERNAL "SAFE" (With Leader)
-- Uses register "0". This register only stores what you explicitly COPIED (y).
-- It is NEVER polluted by things you deleted (dd). It's your "safe" backup.
map({ "n", "v" }, "<leader>y", [["0y]], { desc = "Copy (safe register 0)" })
map({ "n", "v" }, "<leader>p", [["0p]], { desc = "Paste the last copy (safe register 0)" })

-- 3. PASTE DELETED (Mnemonic: Paste Deleted)
-- If you used 'dd' or 'x', the text goes to the default register (").
-- Use this shortcut to recover something you just deleted.
map({ "n", "v" }, "<leader>dp", [[""p]], { desc = "Paste what was deleted" })

-- 4. VIEW REGISTERS (Telescope)
-- When in doubt, open the visual menu to choose what to paste
map("n", '<leader>"', "<cmd>Telescope registers<cr>", with("Registers (pick one to paste)"))

-- 5. Promote Register to System (Utility)
-- <Space> + y + c -> Asks which register to send to the system
map("n", "<leader>yc", function()
    local char = vim.fn.input("Which register to send to system? ")
    if char ~= "" then
        local content = vim.fn.getreg(char)
        if content == "" then
            print(" Register '" .. char .. "' is empty!")
            return
        end
        vim.fn.setreg("+", content)
        print(" Contents of '" .. char .. "' sent to Clipboard!")
    end
end, with("Send a register to the system clipboard"))

-- --- SHORTCUTS ---
-- Every shortcut of Neovim and tmux in one search (tmux: prefix + ?)
map("n", "<leader>fk", function()
    require("config.shortcuts").pick()
end, with("Find a shortcut (Neovim and tmux)"))
vim.api.nvim_create_user_command("Shortcuts", function()
    require("config.shortcuts").pick()
end, { desc = "Find a shortcut (Neovim and tmux)" })

-- tmux's sessions and project folders (tmux: prefix + P)
map("n", "<leader>fP", function()
    require("config.projects").pick()
end, with("Find a project or tmux session"))
