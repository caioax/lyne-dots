-- Shows the keys that can follow a prefix (Space, g, ], z, ", Ctrl+w...)
-- with each map's desc, grouped by task. <leader>? lists the keys of the
-- current buffer (LSP, git); the search across Neovim and tmux is tmux's
-- prefix + ?
return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "modern",
		spec = {
			{ "<leader>f", group = "Find" },
			{ "<leader>g", group = "Git" },
			{ "<leader>l", group = "Lazygit" },
			{ "<leader>q", group = "Sessions" },
			{ "<leader>s", group = "Scratch" },
			{ "<leader>u", group = "Interface" },
			{ "<leader>d", group = "Deleted text" },
			{ "<leader>r", group = "Refactor" },
			{ "<leader>c", group = "Code" },
			{ "<leader>m", group = "Format" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Keys of this buffer",
		},
	},
}
