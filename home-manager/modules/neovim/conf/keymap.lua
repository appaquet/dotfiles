-- Setup leader key as space.
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.keymap.set("", "<Space>", "<Nop>")

-- Buffer navigation & control
require("bufdel").setup({
	quit = false, -- don't quit on last close
})

-- TODO: Move buffer to separate file
-- Buffer management (b)
-- Use `bufferline` commands to manipulate since ordering is handled by the plugin
vim.keymap.set("n", "<Leader>b1", ":BufferLineGoToBuffer 1<CR>", { silent = true, desc = "Buf: Switch 1" })
vim.keymap.set("n", "<Leader>b2", ":BufferLineGoToBuffer 2<CR>", { silent = true, desc = "Buf: Switch 2" })
vim.keymap.set("n", "<Leader>b3", ":BufferLineGoToBuffer 3<CR>", { silent = true, desc = "Buf: Switch 3" })
vim.keymap.set("n", "<Leader>b4", ":BufferLineGoToBuffer 4<CR>", { silent = true, desc = "Buf: Switch 4" })
vim.keymap.set("n", "<Leader>b5", ":BufferLineGoToBuffer 5<CR>", { silent = true, desc = "Buf: Switch 5" })
vim.keymap.set("n", "<Leader>b6", ":BufferLineGoToBuffer 6<CR>", { silent = true, desc = "Buf: Switch 6" })
vim.keymap.set("n", "<Leader>b7", ":BufferLineGoToBuffer 7<CR>", { silent = true, desc = "Buf: Switch 7" })
vim.keymap.set("n", "<Leader>b8", ":BufferLineGoToBuffer 8<CR>", { silent = true, desc = "Buf: Switch 8" })
vim.keymap.set("n", "<Leader>b9", ":BufferLineGoToBuffer 9<CR>", { silent = true, desc = "Buf: Switch 9" })
vim.keymap.set("n", "]b", ":BufferLineCycleNext<CR>", { silent = true, desc = "Buf: Next" })
vim.keymap.set("n", "[b", ":BufferLineCyclePrev<CR>", { silent = true, desc = "Buf: Previous" })
vim.keymap.set("n", "<Leader>b<Tab>", ":b#<CR>", { silent = true, desc = "Buf: Switch to last buffer" })

vim.keymap.set("n", "<Leader>bl", ":BufferLineMoveNext<CR>", { silent = true, desc = "Buf: Move right" })
vim.keymap.set("n", "<Leader>bh", ":BufferLineMovePrev<CR>", { silent = true, desc = "Buf: Move left" })

vim.keymap.set("n", "<Leader>bc", ":enew<CR>", { silent = true, desc = "Buf: New" })
vim.keymap.set("n", "<Leader>bp", ":BufferLineTogglePin<CR>", { silent = true, desc = "Buf: Toggle pin" })

vim.keymap.set("n", "<Leader>bq", ":BufDel<CR>", { silent = true, desc = "Buf: Close current" })
vim.keymap.set("n", "<Leader>bqq", ":BufDel<CR>", { silent = true, desc = "Buf: Close current" })
vim.keymap.set("n", "<Leader>bqo", ":BufDelOthers<CR>", { silent = true, desc = "Buf: Close others" })
vim.keymap.set("n", "<Leader>bqa", ":BufDelAll<CR>", { silent = true, desc = "Buf: Close all" }) -- TODO: Need a way to close all but pinned
vim.keymap.set("n", "<Leader>bqh", ":BufferLineCloseLeft<CR>", { silent = true, desc = "Buf: Close at left" })
vim.keymap.set("n", "<Leader>bql", ":BufferLineCloseRight<CR>", { silent = true, desc = "Buf: Close at right" })

vim.keymap.set("n", "<Leader>w", ":w<CR>", { silent = true, desc = "Buf: Save" })
vim.keymap.set("n", "<Leader>ww", ":w<CR>", { silent = true, desc = "Buf: Save" })
vim.keymap.set("n", "<Leader>wa", ":wa<CR>", { silent = true, desc = "Buf: Save all" })
vim.keymap.set("n", "<C-s>", ":w<CR>", { silent = true, desc = "Buf: Save" })

-- Tab management (n)
vim.keymap.set("n", "<Leader>nc", ":tabnew<CR>", { silent = true, desc = "Tab: New" })
vim.keymap.set("n", "<Leader>nq", ":tabclose<CR>", { silent = true, desc = "Tab: Close current" })
vim.keymap.set("n", "]n", ":tabnext<CR>", { silent = true, desc = "Tab: Next" })
vim.keymap.set("n", "<Leader>nn", ":tabnext<CR>", { silent = true, desc = "Tab: Next" })
vim.keymap.set("n", "[n", ":tabprev<CR>", { silent = true, desc = "Tab: Previous" })
vim.keymap.set("n", "<Leader>np", ":tabprev<CR>", { silent = true, desc = "Tab: Previous" })
vim.keymap.set("n", "<Leader>n1", ":tabfirst<CR>", { silent = true, desc = "Tab: Switch to 1" })
vim.keymap.set("n", "<Leader>n2", ":tabfirst<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 2" })
vim.keymap.set("n", "<Leader>n3", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 3" })
vim.keymap.set("n", "<Leader>n4", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 4" })
vim.keymap.set("n", "<Leader>n5", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 5" })
vim.keymap.set("n", "<Leader>n6", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 6" })
-- TODO: add rename (`BufferLineTabRename`), but need a way to input text

-- Window/splits
vim.keymap.set("n", "<Leader>qq", ":q<CR>", { silent = true, desc = "Quit current split/window" })
vim.keymap.set("n", "<Leader>qa", ":qa<CR>", { silent = true, desc = "Quit nvim" })
vim.keymap.set("n", "<Leader>qs", ":SessionDelete<CR>:qa<CR>", { silent = true, desc = "Clear session & quit nvim" })

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

------------------
-- Whichkey
-- https://github.com/folke/which-key.nvim
local wk = require("which-key")
wk.add({
	{ "<leader>f", group = "file" }, -- group
})
