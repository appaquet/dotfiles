-- mini.notify
-- https://github.com/nvim-mini/mini.notify
local mini_notify = require("mini.notify")
mini_notify.setup({
	lsp_progress = {
		enable = not vim.g.minimal_nvim,
	},
	window = {
		-- Maximum window width as share (between 0 and 1) of available columns
		max_width_share = 0.20, -- max 20% of available width

		-- Value of 'winblend' option
		winblend = 10,
	},
})

vim.notify = mini_notify.make_notify({
	ERROR = { duration = 5000 },
	WARN = { duration = 3000 },
	INFO = { duration = 2000 },
})
