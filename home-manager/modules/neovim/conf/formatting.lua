
-------------------
-- Formatting
-- https://github.com/stevearc/conform.nvim
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "isort", "black" },
    javascript = { "prettierd", "prettier", stop_after_first = true },
    sh = { "shfmt" },

    -- Already handled by their plugins
    -- go = { "gofmt", "goimports" },
    -- rust = { "rustfmt" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_format = "fallback",
  },
})
