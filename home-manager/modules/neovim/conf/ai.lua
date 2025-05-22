require("which-key").add({
	{ "<leader>a", group = "Avante" },
})

-- copilot
-- https://github.com/zbirenbaum/copilot.lua
require("copilot").setup({
	suggestion = {
		enabled = true,
		auto_trigger = true,
		keymap = {
			accept = false, -- See below
			accept_word = "<M-l>",
			accept_line = "<M-j>",
			next = "<M-j>",
			prev = "<M-k>",
			dismiss = "<C-]>",
		},
	},
	panel = { enabled = false }, -- prevent interfering with cmp
	copilot_model = "gpt-4o-copilot",

	-- Logged to ~/.local/state/nvim/copilot-lua.log
	-- logger = {
	-- 	file_log_level = vim.log.levels.TRACE,
	-- 	trace_lsp = "debug",
	-- },

	filetypes = {
		-- overrides defaults
		markdown = true,
		yaml = true,
	},
})

local function passthrough_keymap(keymap)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keymap, true, false, true), "n", true)
end

-- Add completion on tab (if visible), but real tab via shift-tab
local cs = require("copilot.suggestion")
local luasnip = require("luasnip")
vim.keymap.set("i", "<Tab>", function()
	if cs.is_visible() then
		cs.accept()
	elseif luasnip.expand_or_jumpable() then
		luasnip.expand_or_jump()
	else
		passthrough_keymap("<Tab>")
	end
end, { noremap = true, silent = true })
vim.keymap.set("i", "<S-Tab>", function()
	passthrough_keymap("<Tab>")
end, { noremap = true, silent = true })

-- avante
-- https://github.com/yetone/avante.nvim
require("avante_lib").load()
require("avante").setup({
	-- From https://github.com/yetone/avante.nvim/blob/main/lua/avante/config.lua
	provider = "claude",

	behaviour = {
		auto_suggestions = false, -- I use copilot.lua
		use_cwd_as_project_root = true, -- Fix invalid path if inside sub-directory
	},

	claude = {
		model = "claude-sonnet-4-20250514",
	},

	hints = { enabled = false }, -- Keymap hints, we know how to use it now, no need...

	web_search_engine = {
		provider = "tavily",
	},
})

-- needed for avante
require("render-markdown").setup({
	file_types = { "markdown", "Avante" },
})

-- codecompanion
-- https://codecompanion.olimorris.dev/getting-started.html
require("codecompanion").setup({
	strategies = {
		chat = {
			adapter = "copilot",
		},
		inline = {
			adapter = "copilot",
		},
	},
})
