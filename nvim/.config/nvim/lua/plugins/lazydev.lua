-- lua_ls knows Neovim's API (vim.*) and the plugins' types while editing
-- this config or a plugin, and only the modules a file uses are loaded
return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			-- vim.uv's types, once a file uses it
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
		},
	},
}
