-- "lyne" colorscheme: one look for every shell theme (presets, custom themes
-- and Material You), from the palette the shell writes to
-- ~/.cache/lyne/nvim.json. `:colorscheme lyne` re-reads it, which is how the
-- shell updates running instances.

local M = {}

-- Semantic palette of the last load (lualine and others read it)
M.colors = nil

function M.load()
	local palette = require("lyne.palette")
	local src = palette.read()
	local p = palette.build(src)
	M.colors = p

	if vim.g.colors_name then
		vim.cmd("hi clear")
	end
	vim.o.termguicolors = true
	-- Changing 'background' reloads the active colorscheme, so only when needed
	local background = p.light and "light" or "dark"
	if vim.o.background ~= background then
		vim.o.background = background
	end
	vim.g.colors_name = "lyne"

	for group, spec in pairs(require("lyne.groups")(p)) do
		vim.api.nvim_set_hl(0, group, spec)
	end

	-- :terminal buffers use the same ANSI colors as kitty
	for i = 0, 15 do
		local color = src.terminal["color" .. i]
		if color then
			vim.g["terminal_color_" .. i] = color
		end
	end
end

-- Palette for code that runs before or without the colorscheme
function M.palette()
	if not M.colors then
		local palette = require("lyne.palette")
		M.colors = palette.build(palette.read())
	end
	return M.colors
end

return M
