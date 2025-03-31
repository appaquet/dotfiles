-- nvim-notify
-- https://github.com/rcarriga/nvim-notify
local notify = require("notify")
notify.setup({})

---@diagnostic disable-next-line: inject-field
vim.notify = notify

-- lsp-notify
-- Show LSP related messages and progress
-- https://github.com/brianhuster/nvim-lsp-notify/
require("lsp-notify").setup({
	excludes = {
		"buf_ls", -- spams on each change
	},
})
