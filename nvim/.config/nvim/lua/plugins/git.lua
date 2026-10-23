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
				-- Useful Git shortcuts (optional but recommended)
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns
					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end

					-- Navigate between changes (hunk)
					map("n", "]c", function()
						if vim.wo.diff then
							return "]c"
						end
						vim.schedule(function()
							gs.nav_hunk("next")
						end)
						return "<Ignore>"
					end, { expr = true, desc = "Next git change" })

					map("n", "[c", function()
						if vim.wo.diff then
							return "[c"
						end
						vim.schedule(function()
							gs.nav_hunk("prev")
						end)
						return "<Ignore>"
					end, { expr = true, desc = "Previous git change" })

					-- Actions
					map("n", "<leader>gb", gs.toggle_current_line_blame, { desc = "Git Blame (Line)" })
					map("n", "<leader>gd", gs.diffthis, { desc = "Git Diff" })
					map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview Change" })
				end,
			})
		end,
	},
}
