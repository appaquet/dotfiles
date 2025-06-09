-- copilot
-- https://github.com/zbirenbaum/copilot.lua
require("copilot").setup({
	suggestion = {
		enabled = true,
		auto_trigger = true,
		keymap = {
			accept = false, -- See below
			accept_word = "<M-l>",
			accept_line = "<M-o>",
			next = "<M-j>",
			prev = "<M-k>",
			dismiss = "<C-]>",
		},
	},
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

require("copilot-lsp").setup({})
vim.g.copilot_nes_debounce = 500
vim.lsp.enable("copilot_ls")

-- Add completion on tab (if visible), but real tab via shift-tab
local cs = require("copilot.suggestion")
local luasnip = require("luasnip")
vim.keymap.set({ "n", "i" }, "<Tab>", function()
	if cs.is_visible() then
		cs.accept()
	elseif vim.b[vim.api.nvim_get_current_buf()].nes_state then
		require("copilot-lsp.nes").apply_pending_nes()
		require("copilot-lsp.nes").walk_cursor_end_edit()
	elseif luasnip.expand_or_jumpable() then
		luasnip.expand_or_jump()
	else
		passthrough_keymap("<Tab>")
	end
end, { noremap = true, silent = true })
vim.keymap.set("i", "<S-Tab>", function()
	passthrough_keymap("<Tab>")
end, { noremap = true, silent = true })

vim.keymap.set("i", "<M-p>", function()
	vim.cmd("Copilot panel")
end, { noremap = true, silent = true })
