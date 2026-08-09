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
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = "",
        desc = "Format current buffer",
      },
    },
    -- HERE IS THE CONFIGURATION THAT WAS MISSING IN THE CORRECT BLOCK
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
          stylua = {
            prepend_args = { "--indent-type", "Spaces", "--indent-width", "4" },
          },
        },

        -- Configure Format on Save
        format_on_save = {
          -- If no formatter is available (e.g. C++, Rust), use native LSP
          lsp_fallback = true,
          async = false,
          timeout_ms = 500,
        },
      })
    end,
  },
}
