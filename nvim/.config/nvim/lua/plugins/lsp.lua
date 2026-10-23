return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason-org/mason.nvim",
			"mason-org/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
		config = function()
			-- ========================================================================
			-- 1. VISUAL CONFIGURATION (Diagnostic) - Modern Version (Neovim 0.10+)
			-- ========================================================================
			vim.diagnostic.config({
				-- Inline text: DISABLED (Visual cleanliness)
				virtual_text = false,

				-- Error underline: ENABLED
				underline = true,

				-- Gutter icons: ENABLED
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = "",
						[vim.diagnostic.severity.WARN] = "",
						[vim.diagnostic.severity.HINT] = "",
						[vim.diagnostic.severity.INFO] = "",
					},
				},

				-- Do not update while typing
				update_in_insert = false,

				-- Sorting: Severe errors first
				severity_sort = true,
			})

			-- ========================================================================
			-- 2. GLOBAL KEYBINDINGS DEFINITION (LspAttach)
			-- ========================================================================
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(event)
					local map = function(keys, func, desc)
						vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end

					-- === CUSTOM SHORTCUT ===
					-- [gl] = Go Line Diagnostic
					map("gl", function()
						vim.diagnostic.open_float({
							scope = "line",
							border = "rounded",
							source = true,
							header = "",
							prefix = "",
						})
					end, "View Line Error (Float)")

					-- Default Keybindings
					map("gd", require("telescope.builtin").lsp_definitions, "Go to Definition")
					-- grr is Neovim's own key for references (with grn rename,
					-- gra code action, gri implementation): in Telescope here
					map("grr", require("telescope.builtin").lsp_references, "Go to References")
					map("K", vim.lsp.buf.hover, "Hover Documentation")
					map("<leader>rn", vim.lsp.buf.rename, "Rename Variable")
					map("<leader>ca", vim.lsp.buf.code_action, "Code Action")

					-- Quick navigation between errors: [d and ]d are Neovim's own
				end,
			})

			-- ========================================================================
			-- 3. MASON INITIALIZATION
			-- ========================================================================
			require("mason").setup()

			require("mason-tool-installer").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"html",
					"cssls",
					"bashls",
					"pyright",
					"jsonls",
					"yamlls",
					"stylua",
					"prettier",
					"black",
					"isort",
					"shfmt",
					"eslint_d",
					"clangd",
					"omnisharp",
					"intelephense",
					"php-cs-fixer",
				},
			})

			-- Every server gets what nvim-cmp can handle (preselect, commit
			-- characters...) on top of Neovim's own capabilities
			vim.lsp.config("*", {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			})

			-- mason-lspconfig v2 enables every installed server on its own
			-- (vim.lsp.enable). stylua is installed as a formatter for conform
			-- and would start as a server on every Lua file too
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"html",
					"cssls",
					"bashls",
					"pyright",
					"jsonls",
					"yamlls",
					"tailwindcss",
					"clangd",
					"omnisharp",
					"intelephense",
				},
				automatic_enable = {
					exclude = { "stylua" },
				},
			})
		end,
	},
}
