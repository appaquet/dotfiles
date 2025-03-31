-- nvim-notify
-- https://github.com/rcarriga/nvim-notify
local notify = require("notify")
notify.setup({})

---@diagnostic disable-next-line: inject-field
vim.notify = notify

require("lsp-notify").setup({})
