-- Linting
-- https://github.com/mfussenegger/nvim-lint
-- Most linters are hooked via the respective LSP.
local lint = require("lint")
lint.linters_by_ft = {
	markdown = { "markdownlint" },
}

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
	callback = function()
		lint.try_lint()
	end,
})

-- Override markdownlint args to disable line length check
-- https://github.com/mfussenegger/nvim-lint/blob/2b0039b8be9583704591a13129c600891ac2c596/lua/lint/linters/markdownlint.lua#L6
local markdownlint = lint.linters["markdownlint"]
markdownlint.args = {
	"--stdin",
	"--disable",
	"MD013", -- Disable line length check
	"MD012", -- Disable multiple consecutive blank lines
}
