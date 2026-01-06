return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = {
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Buscar Arquivos" },
		{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Buscar Texto" },
		{ "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Arquivos Abertos" },
	},
	config = function()
		require("telescope").setup({
			defaults = {
				path_display = { "tail" }, -- Mostra apenas o nome do arquivo, esconde o caminho longo
				file_ignore_patterns = { "node_modules", ".git" }, -- Ignora pastas pesadas
			},
		})
	end,
}
