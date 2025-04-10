require("which-key").add({
	{ "<leader>b", group = "Buffers" },
	{ "<leader>n", group = "Tabs" },
	{ "<leader>w", group = "Save" },
})

-- bufferline
-- https://github.com/akinsho/bufferline.nvim
require("bufferline").setup({
	options = {
		show_duplicate_prefix = true,

		diagnostics = "nvim_lsp",
		diagnostics_indicator = function(count, level)
			local icon = level:match("error") and " " or " "
			return " " .. icon .. count
		end,

		offsets = { -- Don't show tabs over file explorer
			{
				filetype = "NvimTree",
				text = "File Explorer",
				text_align = "center",
				separator = true,
			},
		},
	},
})

-- Buffer deletion
-- https://github.com/famiu/bufdelete.nvim
require("bufdel").setup({
	quit = false, -- don't quit on last close
})

-- Buffer management (b)
vim.keymap.set("n", "<Leader>1", ":BufferLineGoToBuffer 1<CR>", { silent = true, desc = "Buf: Switch 1" })
vim.keymap.set("n", "<Leader>2", ":BufferLineGoToBuffer 2<CR>", { silent = true, desc = "Buf: Switch 2" })
vim.keymap.set("n", "<Leader>3", ":BufferLineGoToBuffer 3<CR>", { silent = true, desc = "Buf: Switch 3" })
vim.keymap.set("n", "<Leader>4", ":BufferLineGoToBuffer 4<CR>", { silent = true, desc = "Buf: Switch 4" })
vim.keymap.set("n", "<Leader>5", ":BufferLineGoToBuffer 5<CR>", { silent = true, desc = "Buf: Switch 5" })
vim.keymap.set("n", "<Leader>6", ":BufferLineGoToBuffer 6<CR>", { silent = true, desc = "Buf: Switch 6" })
vim.keymap.set("n", "<Leader>7", ":BufferLineGoToBuffer 7<CR>", { silent = true, desc = "Buf: Switch 7" })
vim.keymap.set("n", "<Leader>8", ":BufferLineGoToBuffer 8<CR>", { silent = true, desc = "Buf: Switch 8" })
vim.keymap.set("n", "<Leader>9", ":BufferLineGoToBuffer 9<CR>", { silent = true, desc = "Buf: Switch 9" })
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
vim.keymap.set("n", "<Leader>bqa", ":BufDelAll<CR>", { silent = true, desc = "Buf: Close all" })
vim.keymap.set("n", "<Leader>bqh", ":BufferLineCloseLeft<CR>", { silent = true, desc = "Buf: Close at left" })
vim.keymap.set("n", "<Leader>bql", ":BufferLineCloseRight<CR>", { silent = true, desc = "Buf: Close at right" })

vim.keymap.set("n", "<Leader>w", ":w<CR>", { silent = true, desc = "Buf: Save" })
vim.keymap.set("n", "<Leader>ww", ":w<CR>", { silent = true, desc = "Buf: Save" })
vim.keymap.set("n", "<Leader>wa", ":wa<CR>", { silent = true, desc = "Buf: Save all" })
vim.keymap.set("n", "<C-s>", ":w<CR>", { silent = true, desc = "Buf: Save" })

-- Tab management (n)
vim.keymap.set("n", "<Leader>nc", ":tabnew<CR>", { silent = true, desc = "Tab: New" })
vim.keymap.set("n", "]n", ":tabnext<CR>", { silent = true, desc = "Tab: Next" })
vim.keymap.set("n", "[n", ":tabprev<CR>", { silent = true, desc = "Tab: Previous" })
vim.keymap.set("n", "<Leader>n1", ":tabfirst<CR>", { silent = true, desc = "Tab: Switch to 1" })
vim.keymap.set("n", "<Leader>n2", ":tabfirst<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 2" })
vim.keymap.set("n", "<Leader>n3", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 3" })
vim.keymap.set("n", "<Leader>n4", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 4" })
vim.keymap.set("n", "<Leader>n5", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 5" })
vim.keymap.set("n", "<Leader>n6", ":tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>", { silent = true, desc = "Tab: Switch to 6" })
vim.keymap.set("n", "<Leader>nq", ":tabclose<CR>", { silent = true, desc = "Tab: Close current" })
-- TODO: add rename (`BufferLineTabRename`), but need a way to input text

-- Windows
vim.keymap.set("n", "<Leader>qq", ":q<CR>", { silent = true, desc = "Quit current split/window" })
vim.keymap.set("n", "<Leader>qa", ":qa<CR>", { silent = true, desc = "Quit nvim" })
vim.keymap.set("n", "<Leader>qs", ":SessionDelete<CR>:qa<CR>", { silent = true, desc = "Clear session & quit nvim" })

-- Zenmode
local zenmode = require("zen-mode")
vim.keymap.set({ "n", "v" }, "<C-w>z", zenmode.toggle, { silent = true })
