return {
    {
        "hrsh7th/nvim-cmp",
        -- Loads when entering insert mode (avoids slowing down boot)
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = {
            "hrsh7th/cmp-nvim-lsp", -- Source: LSP intelligence
            "hrsh7th/cmp-buffer", -- Source: Current file text
            "hrsh7th/cmp-path", -- Source: File paths
            "hrsh7th/cmp-cmdline", -- Autocomplete for ":" command
            "L3MON4D3/LuaSnip", -- Snippet engine (Required)
            "saadparwaiz1/cmp_luasnip", -- Connects LuaSnip to CMP
            "rafamadriz/friendly-snippets", -- Collection of ready-made snippets
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            -- Load VSCode-style snippets
            require("luasnip.loaders.from_vscode").lazy_load()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(), -- Force open menu
                    ["<C-e>"] = cmp.mapping.abort(), -- Cancel
                    ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Enter confirms

                    -- TAB configuration to navigate the menu
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),

                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    -- Module names in require() of this config (lazydev.nvim,
                    -- Lua files only); group 0 so lua_ls' own list waits
                    { name = "lazydev", group_index = 0 },
                    { name = "nvim_lsp" }, -- High priority: Code intelligence
                    { name = "luasnip" }, -- Snippets
                    { name = "buffer" }, -- Words already in the text
                    { name = "path" }, -- Folder/file paths
                }),
            })
            --- COMMAND LINE CONFIGURATION (:) ---
            -- For search (/ or ?)
            cmp.setup.cmdline({ "/", "?" }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = "buffer" },
                },
            })

            -- For commands (:)
            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = "path" }, -- Autocomplete file paths
                }, {
                    { name = "cmdline" }, -- Autocomplete commands
                }),
                matching = { disallow_symbol_nonprefix_matching = false },
            })
        end,
    },
}
