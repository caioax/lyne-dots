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
							source = "always",
							header = "",
							prefix = "",
						})
					end, "View Line Error (Float)")

					-- Default Keybindings
					map("gd", require("telescope.builtin").lsp_definitions, "Go to Definition")
					map("gr", require("telescope.builtin").lsp_references, "Go to References")
					map("K", vim.lsp.buf.hover, "Hover Documentation")
					map("<leader>rn", vim.lsp.buf.rename, "Rename Variable")
					map("<leader>ca", vim.lsp.buf.code_action, "Code Action")

					-- Quick navigation between errors
					map("[d", function()
						vim.diagnostic.goto_prev({ float = false })
					end, "Previous Error")
					map("]d", function()
						vim.diagnostic.goto_next({ float = false })
					end, "Next Error")
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
				},
			})

			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"html",
					"cssls",
					"bashls",
					"pyright",
					"tailwindcss",
					"clangd",
					"omnisharp",
				},
				automatic_installation = true,
				handlers = {
					function(server_name)
						local capabilities = require("cmp_nvim_lsp").default_capabilities()
						require("lspconfig")[server_name].setup({
							capabilities = capabilities,
						})
					end,
				},
			})
		end,
	},
}
