-- Setup leader key as space.
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.keymap.set("", "<Space>", "<Nop>")

-- Clipboard operations
vim.keymap.set("v", "<Leader>y", ":w !pbcopy<CR><CR>", { desc = "Copy current file content to system clipboard" })
vim.keymap.set("n", "<Leader>yp", ":read !pbpaste<CR>", { desc = "Paste from system clipboard" })
vim.keymap.set("n", "<Leader>Tm", function()
	if vim.o.mouse == "a" then
		vim.o.mouse = ""
		vim.o.relativenumber = false
		vim.o.number = false
	else
		vim.o.mouse = "a"
		vim.o.relativenumber = true
		vim.o.number = true
	end
end, { silent = true, desc = "Toggle mouse support" })

-- Marks (m[a-z0-9A-Z], 'a-z0-9A-Z)
vim.keymap.set("n", "<Leader>mk", ":delmarks a-z0-9<CR>", { silent = true, desc = "Marks: delete all" })

-- Command-line mappings for "sudo save" and quick quit commands
vim.cmd([[
  cnoremap w!! w !sudo tee % >/dev/null
  cnoremap wq wqa
  cnoremap Wq wqa
  cnoremap Wqa wqa
  cnoremap WQ wqa
  cnoremap WQa wqa
  cnoremap wqaa wqa
  cnoremap WQaa wqa
  cnoremap Qw wqq
  cnoremap qw wqq
]])

-- Misc
vim.keymap.set("n", "<Leader>r", ":w<CR>:!./%<CR>", { silent = true, desc = "Save and execute current file" })
vim.keymap.set("v", "<Leader>r", ":w !sh<CR>", { silent = true, desc = "Execute selected lines in shell" })

local function toggle_wrap()
	if vim.wo.wrap then
		vim.wo.wrap = false
		vim.wo.linebreak = false
	else
		vim.wo.wrap = true
		vim.wo.linebreak = true
	end
end
vim.keymap.set("n", "<Leader>Tw", toggle_wrap, { silent = true, desc = "Toggle line wrap" })

-- Spellcheck
vim.keymap.set("n", "<Leader>Ts", ":set spell!<CR>", { silent = true, desc = "Toggle spellcheck" })

-- Whichkey
-- https://github.com/folke/which-key.nvim
local wk = require("which-key")
wk.add({
	{ "<leader>f", group = "file" }, -- group
})
