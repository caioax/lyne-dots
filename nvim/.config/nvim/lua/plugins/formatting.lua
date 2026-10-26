return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" }, -- Loads before saving
        cmd = { "ConformInfo" },
        keys = {
            {
                -- Manual format shortcut: Leader + mp
                "<leader>mp",
                function()
                    require("conform").format({ async = true, lsp_format = "fallback" })
                end,
                mode = "",
                desc = "Format current buffer",
            },
        },
        config = function()
            require("conform").setup({
                -- Define which formatters to use for each language
                formatters_by_ft = {
                    lua = { "stylua" },

                    -- Python
                    python = { "isort", "black" },

                    -- Web (Prettier for everything)
                    javascript = { "prettier" },
                    typescript = { "prettier" },
                    javascriptreact = { "prettier" },
                    typescriptreact = { "prettier" },
                    css = { "prettier" },
                    html = { "prettier" },
                    json = { "prettier" },
                    yaml = { "prettier" },
                    markdown = { "prettier" },

                    -- PHP
                    php = { "php_cs_fixer" },

                    -- Shell
                    sh = { "shfmt" },
                    bash = { "shfmt" },
                },

                formatters = {
                    prettier = {
                        prepend_args = { "--tab-width", "4" },
                    },
                    shfmt = {
                        prepend_args = { "-i", "4" },
                    },
                    -- A project's stylua.toml (lyne-dots has one) wins; 4
                    -- spaces only for Lua outside any
                    stylua = {
                        prepend_args = function(_, ctx)
                            local config =
                                vim.fs.find({ ".stylua.toml", "stylua.toml" }, { upward = true, path = ctx.dirname })[1]
                            if config then
                                return {}
                            end
                            return { "--indent-type", "Spaces", "--indent-width", "4" }
                        end,
                    },
                },

                -- Configure Format on Save
                format_on_save = {
                    -- If no formatter is available (e.g. C++, Rust), use native LSP
                    lsp_format = "fallback",
                    async = false,
                    timeout_ms = 500,
                },
            })
        end,
    },
}
