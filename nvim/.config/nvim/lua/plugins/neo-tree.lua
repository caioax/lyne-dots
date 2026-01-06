return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	keys = {
		{ "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Explorer (Toggle)" },
	},
	config = function()
		require("neo-tree").setup({
			window = {
				width = 30, -- Largura da janela lateral
				mappings = {
					["l"] = "open", -- l: Abre pasta ou arquivo
					["h"] = "close_node", -- h: Fecha a pasta (colapsa)
					["<space>"] = "none",
				},
			},
			filesystem = {
				filtered_items = {
					visible = true,
					hide_dotfiles = false,
					hide_gitignored = false,
				},
				follow_current_file = { enabled = true },
			},
		})
	end,
}
