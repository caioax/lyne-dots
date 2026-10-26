return {
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter", -- Only loads when you start typing
        -- Integration with the autocomplete menu (CMP)
        -- If you press Enter in the suggestion menu, it adjusts the parentheses
        dependencies = { "hrsh7th/nvim-cmp" },
        -- In config, not init: init runs at startup, and requiring cmp there
        -- loaded it (and its sources) before any typing
        config = function()
            require("nvim-autopairs").setup()
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    },
}
