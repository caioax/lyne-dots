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
                -- The message at the end of the line (gl shows it all in a float)
                virtual_text = {
                    spacing = 4,
                    source = "if_many",
                },

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
                -- The keys are in config/buffer_keys.lua (the shortcut search lists
                -- them too)
                callback = function(event)
                    require("config.buffer_keys").apply("lsp", event.buf)
                end,
            })

            -- ========================================================================
            -- 3. MASON INITIALIZATION
            -- ========================================================================
            require("mason").setup()

            -- C#: Roslyn (the server VS Code uses) through nvim-lspconfig's
            -- roslyn_ls. Mason installs it with dotnet, so it is only asked
            -- for where .NET is installed, or the install fails on every start
            local has_dotnet = vim.fn.executable("dotnet") == 1

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
                    "intelephense",
                    "php-cs-fixer",
                    -- last: a nil in the middle would cut the list short
                    has_dotnet and "roslyn-language-server" or nil,
                },
            })

            -- Every server gets what nvim-cmp can handle (preselect, commit
            -- characters...) on top of Neovim's own capabilities
            vim.lsp.config("*", {
                capabilities = require("cmp_nvim_lsp").default_capabilities(),
            })

            -- lspconfig's roslyn_ls checks the version with a bare --version,
            -- which roslyn-language-server 5.12 answers only next to --stdio, so
            -- it warned "projects won't be loaded" on every start although they
            -- load (--autoLoadProjects is passed either way)
            vim.lsp.config("roslyn_ls", {
                before_init = function() end,
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
                    "intelephense",
                    has_dotnet and "roslyn_ls" or nil, -- last, as above
                },
                -- OmniSharp was the C# server before Roslyn: where Mason still
                -- has it, it must not start next to roslyn_ls
                automatic_enable = {
                    exclude = { "stylua", "omnisharp" },
                },
            })

            -- QML: qmlls comes with Qt (qt6-declarative, a dependency of
            -- Quickshell), not Mason, and Arch names it qmlls6. It finds
            -- Quickshell's modules through the .qmlls.ini Quickshell fills in
            -- next to shell.qml (lyne-dots creates the empty file), so that
            -- folder is the project
            if vim.fn.executable("qmlls6") == 1 then
                vim.lsp.config("qmlls", {
                    cmd = { "qmlls6" },
                    root_markers = { ".qmlls.ini", "shell.qml", ".git" },
                })
                vim.lsp.enable("qmlls")
            end
        end,
    },
}
