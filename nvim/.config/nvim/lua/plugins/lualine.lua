return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Colors come from the "lyne" colorscheme palette, rebuilt on every
		-- theme change (ColorScheme below)
		local function setup()
			local p = require("lyne").palette()

			local custom_theme = {
				normal = {
					a = { bg = p.func, fg = p.bg, gui = "bold" },
					b = { bg = p.bg_float, fg = p.fg },
					c = { bg = p.bg_dark, fg = p.fg_dim },
				},
				insert = {
					a = { bg = p.string, fg = p.bg_dark, gui = "bold" },
					b = { bg = p.bg_float, fg = p.fg },
					c = { bg = p.bg_dark, fg = p.fg_dim },
				},
				visual = {
					a = { bg = p.class, fg = p.bg_dark, gui = "bold" },
					b = { bg = p.bg_float, fg = p.fg },
					c = { bg = p.bg_dark, fg = p.fg_dim },
				},
				replace = {
					a = { bg = p.error, fg = p.bg, gui = "bold" },
					b = { bg = p.bg_float, fg = p.fg },
					c = { bg = p.bg_dark, fg = p.fg_dim },
				},
				command = {
					a = { bg = p.yellow, fg = p.bg, gui = "bold" },
					b = { bg = p.bg_float, fg = p.fg },
					c = { bg = p.bg_dark, fg = p.fg_dim },
				},
				inactive = {
					a = { bg = p.bg_dark, fg = p.fg_dim, gui = "bold" },
					b = { bg = p.bg_dark, fg = p.fg_dim },
					c = { bg = p.bg_dark, fg = p.fg_dim },
				},
			}

			-- Setup Lualine
			require("lualine").setup({
				options = {
					theme = custom_theme, -- Using your custom theme
					component_separators = { left = "|", right = "|" },
					section_separators = { left = "", right = "" },
					globalstatus = true,
					disabled_filetypes = { statusline = { "dashboard", "alpha", "starter" } },
				},
				sections = {
					lualine_a = {
						{ "mode", separator = { left = "" }, right_padding = 2 },
					},
					lualine_b = {
						"branch",
						{ "diff", colored = true },
					},
					lualine_c = {
						{ "filename", path = 1 },
					},
					lualine_x = {
						{
							"diagnostics",
							sources = { "nvim_diagnostic" },
							symbols = { error = " ", warn = " ", info = " " },
							diagnostics_color = {
								error = { fg = p.diag_err },
								warn = { fg = p.diag_warn },
								info = { fg = p.diag_info },
							},
						},
						"filetype",
					},
					lualine_y = { "progress" },
					lualine_z = {
						{ "location", separator = { right = "" }, left_padding = 2 },
					},
				},
			})
		end

		setup()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("lyne_lualine", { clear = true }),
			callback = setup,
		})
	end,
}
