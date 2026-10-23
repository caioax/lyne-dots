return {
	"folke/persistence.nvim",
	event = "BufReadPre", -- Only loads when you open a file
	opts = {
		-- Where to save sessions (default is ~/.local/state/nvim/sessions)
		-- dir = vim.fn.expand(vim.fn.stdpath("state") .. "/sessions/"),

		-- Minimum open buffers to save the session
		need = 1,

		-- Save session based on git branch? (Useful when working on multiple features)
		branch = true,
	},
	-- tmux-resurrect starts Neovim with :RestoreSession in the panes that ran
	-- it (tmux.conf's @resurrect-processes); requiring persistence loads it
	init = function()
		vim.api.nvim_create_user_command("RestoreSession", function()
			require("persistence").load()
		end, { desc = "Restore this folder's session" })
	end,
	config = function(_, opts)
		local persistence = require("persistence")
		persistence.setup(opts)

		-- Saved on quit, and also when a file is written or Neovim loses the
		-- focus: logging out or shutting down ends it with SIGTERM, which
		-- quits without saving. Like on quit, only with a file open (an
		-- empty session would replace the folder's)
		vim.api.nvim_create_autocmd({ "BufWritePost", "FocusLost" }, {
			group = vim.api.nvim_create_augroup("persistence_often", { clear = true }),
			callback = function()
				if not persistence.active() then
					return
				end
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
						persistence.save()
						return
					end
				end
			end,
		})
	end,
	keys = {
		-- Shortcut to restore the session for the current directory
		{
			"<leader>qs",
			function()
				require("persistence").load()
			end,
			desc = "Restore Session",
		},

		-- Shortcut to restore the LAST session you used (any folder)
		{
			"<leader>ql",
			function()
				require("persistence").load({ last = true })
			end,
			desc = "Restore Last Session",
		},

		-- Shortcut to stop recording the current session (useful for quick tasks)
		{
			"<leader>qd",
			function()
				require("persistence").stop()
			end,
			desc = "Don't Save Current Session",
		},
	},
}
