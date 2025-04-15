-- Misc settings
vim.opt.showmatch = true -- show matching brackets/parenthesis
vim.opt.incsearch = true -- find as you type search
vim.opt.hlsearch = true -- highlight search terms
vim.opt.smartcase = true -- case sensitive when uc present
vim.opt.ignorecase = true -- case insensitive search

vim.opt.autoindent = true -- indent at the same level of the previous line
vim.opt.timeoutlen = 505 -- time to wait for a key code sequence to complete, need to be >500 since whichkey detects recursion with 500ms

vim.opt.textwidth = 100 -- max line length, because we aren't on a mainframe anymore
vim.opt.formatoptions:remove("t") -- don't auto-wrap text (but comments will still auto-wrap (+c))

vim.opt.undofile = true -- Persists the undo across sessions

-- Lower cursor hold time (for highlighting)
-- Should not be too low since it writes to swap with this delay as well
vim.opt.updatetime = 500 -- time to wait for a write to disk

-- Line numbers (see keymap.lua for toggling)
vim.opt.relativenumber = true -- relative line numbers
vim.opt.number = true -- show current absolute number instead of 0

-- Defaults to space indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- disable netrw file explorer (because we use nvim-tree)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- support for .nvim.lua or .nvimrc per project
vim.opt.exrc = true

-- Split behaviour.
vim.opt.splitbelow = true
vim.opt.splitright = true

-- pretty print
-- https://www.reddit.com/r/neovim/comments/xrovld/display_lua_tables_eg_vimkeymap/
function PPrint(v)
	print(vim.inspect(v))
	return v
end

function Try(description, fn)
	local success, result = pcall(fn)
	if not success then
		vim.notify("Failed to execute " .. description .. ": " .. result, vim.log.levels.ERROR)
	end
end
