local opt = vim.opt

opt.number = true -- Show line number
opt.relativenumber = true -- Relative numbers
opt.tabstop = 4 -- Tab size
opt.shiftwidth = 4 -- Indentation size
opt.expandtab = true -- Convert Tab to Spaces
opt.autoindent = true -- Keep indentation on new line
opt.wrap = true -- Wrap long lines visually
opt.linebreak = true -- Wrap at word boundaries, not mid-word
opt.breakindent = true -- Wrapped continuation keeps the indentation
opt.ignorecase = true -- Search ignores case...
opt.smartcase = true -- ...unless you type an uppercase letter
opt.cursorline = true -- Highlight current line
opt.termguicolors = true -- True colors (24-bit)
opt.scrolloff = 8 -- Keep 8 lines of margin when scrolling
-- opt.clipboard = "unnamedplus" -- Integrate with system clipboard

-- Leader Key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ============================================================================
-- FOLD CONFIGURATION
-- ============================================================================
opt.foldmethod = "expr" -- Use Treesitter intelligence to determine where to fold
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

opt.foldlevel = 99 -- Start with everything open (only folds at level 99+)
opt.foldlevelstart = 99 -- Ensure new files open expanded
opt.foldenable = true -- Enable the system (but starts open because of 99)
