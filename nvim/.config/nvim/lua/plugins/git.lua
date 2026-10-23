return {
	-- Gitsigns: Shows colored bars on the left (Add/Change/Delete)
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gitsigns").setup({
				-- Visual configuration of signs
				signs = {
					add = { text = "▎" },
					change = { text = "▎" },
					delete = { text = "" },
					topdelete = { text = "" },
					changedelete = { text = "▎" },
				},
				-- Git keys (config/buffer_keys.lua: the shortcut search lists them
				-- too)
				on_attach = function(bufnr)
					require("config.buffer_keys").apply("git", bufnr)
				end,
			})
		end,
	},
}
