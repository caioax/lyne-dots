-- ============================================================================
-- THEME
-- ============================================================================
-- The "lyne" colorscheme (colors/lyne.lua, lua/lyne/) follows the shell
-- theme: the shell writes its palette to ~/.cache/lyne/nvim.json and runs
-- `:colorscheme lyne` in every open instance when the theme changes.

return {
	{
		dir = vim.fn.stdpath("config"),
		name = "lyne-theme",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("lyne")
		end,
	},
}
