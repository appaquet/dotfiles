require("which-key").add({
	{ "<leader>x", group = "Diagnostics" },
})

-- Trouble (diagnostics)
-- https://github.com/folke/trouble.nvim
local Trouble = require("trouble")
Trouble.setup({
	modes = {
		-- Only show diagnostics in the current working directory
		cwd_diagnostics = {
			mode = "diagnostics",
			filter = {
				function(item)
					local cwd = vim.fn.getcwd()
					return item.filename:sub(1, #cwd) == cwd
				end,
			},
		},
	},
})

local diag_mode = "cwd_diagnostics"

local function trouble_diag_open()
	Trouble.open(diag_mode)
end

local function trouble_diag_focus()
	if Trouble.is_open(diag_mode) then
		Trouble.focus()
	else
		Trouble.open(diag_mode)
	end
end

local function trouble_diag_close()
	Trouble.close(diag_mode)
end

local function trouble_diag_toggle()
	Trouble.toggle(diag_mode)
end

local function trouble_diag_next()
	if not Trouble.is_open(diag_mode) then
		Trouble.open(diag_mode)
	end

	Trouble.focus()
	Trouble.next()
end

local function trouble_diag_prev()
	if not Trouble.is_open(diag_mode) then
		Trouble.open(diag_mode)
	end

	Trouble.focus()
	Trouble.prev()
end

local function diag_next_infile()
	vim.diagnostic.jump({ count = 1 })
end

local function diag_prev_infile()
	vim.diagnostic.jump({ count = -1 })
end

-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set("n", "<leader>xs", vim.diagnostic.open_float, { desc = "Diag: Open diagnostic float" })
vim.keymap.set("n", "<leader>xf", vim.diagnostic.open_float, { desc = "Diag: Open diagnostic float" })
vim.keymap.set("n", "<leader>xr", trouble_diag_close, { desc = "Diag: Reset diagnostics" })
vim.keymap.set("n", "]x", diag_next_infile, { desc = "Diag: Go to next diagnostic (in file)" })
vim.keymap.set("n", "[x", diag_prev_infile, { desc = "Diag: Go to previous diagnostic (in file)" })
vim.keymap.set("n", "]X", trouble_diag_next, { desc = "Diag: Go to next diagnostic (global)" })
vim.keymap.set("n", "[X", trouble_diag_prev, { desc = "Diag: Go to previous diagnostic (global)" })
vim.keymap.set("n", "<leader>xl", vim.diagnostic.setloclist, { desc = "Diag: Set location list" })
vim.keymap.set("n", "<leader>xo", trouble_diag_open, { desc = "Diag: Open trouble" })
vim.keymap.set("n", "<leader>xf", trouble_diag_focus, { desc = "Diag: Focus trouble" })
vim.keymap.set("n", "<leader>xx", trouble_diag_toggle, { desc = "Diag: Toggle trouble" })
vim.keymap.set("n", "<leader>xq", trouble_diag_close, { desc = "Diag: Close trouble" })
