--------------------------
-- Auto formatting on save
-- https://github.com/stevearc/conform.nvim
require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "isort", "black" },
		javascript = { "prettierd", "prettier", stop_after_first = true },
		sh = { "shfmt" },
		rust = { "rustfmt", lsp_format = "fallback" },

		-- go = { "gofmt", "goimports" }, -- Already handled by the plugin
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_format = "fallback",
	},
	default_format_opts = {
		-- fallback to lsp
		lsp_format = "fallback",
	},
})

vim.keymap.set("n", "<leader>lf", function()
	require("conform").format()
end, { desc = "LSP: Format" })
