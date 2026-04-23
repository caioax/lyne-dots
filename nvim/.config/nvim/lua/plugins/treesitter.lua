return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	config = function()
		local parsers = {
			-- Included by default, you can add your own you want ensure to be installed.
			"c",
			"cpp",
			"c_sharp",
			"lua",
			"markdown",
			"markdown_inline",
			"query",
			"python",
			"bash",
			"vim",
			"vimdoc",
			"javascript",
			"typescript",
			"tsx",
			"html",
			"css",
			"json",
			"yaml",
			"toml",
			"go",
			"rust",
			"java",
			"kotlin",
			"php",
			"ruby",
			"sql",
		}

		-- Install above parsers if they are missing.
		vim.defer_fn(function()
			require("nvim-treesitter").install(parsers)
		end, 1000)

		-- auto-start highlights & indentation
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("Custom_enable_treesitter_features", {}),
			callback = function(args)
				local buf = args.buf
				local filetype = args.match

				-- checks if a parser exists for the current language
				local language = vim.treesitter.language.get_lang(filetype) or filetype
				if not vim.treesitter.language.add(language) then
					return
				end

				-- highlights
				vim.treesitter.start(buf, language)

				-- indent
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				-- folding
				vim.wo.foldmethod = "expr"
				vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
			end,
		})
	end,
}
