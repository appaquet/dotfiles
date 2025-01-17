
-- Buffer navigation & control
require('bufdel').setup {
  quit = false,  -- don't quit on last close
}

vim.keymap.set('n', '<Leader>1', ':br!<CR>', { silent = true, desc = "Buf: Switch 1" })
vim.keymap.set('n', '<Leader>2', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 2" })
vim.keymap.set('n', '<Leader>3', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 3" })
vim.keymap.set('n', '<Leader>4', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 4" })
vim.keymap.set('n', '<Leader>5', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 5" })
vim.keymap.set('n', '<Leader>6', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 6" })
vim.keymap.set('n', '<Leader>7', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 7" })
vim.keymap.set('n', '<Leader>8', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 8" })
vim.keymap.set('n', '<Leader>9', ':br!<CR>:bn!<CR>', { silent = true, desc = "Buf: Switch 9" })
vim.keymap.set('n', '<Leader>]', ':bn!<CR>', { silent = true, desc = "Buf: Next" })
vim.keymap.set('n', '<Leader>[', ':bp!<CR>', { silent = true, desc = "Buf: Previous" })
vim.keymap.set('n', '<Leader>w', ':BufDel<CR>', { silent = true, desc = "Buf: Close current" })
vim.keymap.set('n', '<Leader>wo', ':BufDelOthers<CR>', { silent = true, desc = "Buf: Close others" })
vim.keymap.set('n', '<Leader>wa', ':BufDelAll<CR>', { silent = true, desc = "Buf: Close all" })

-- Tab navigation
vim.keymap.set('n', '<Leader>ln', ':tabnew<CR>', { silent = true, desc = "Tab: New" })
vim.keymap.set('n', '<Leader>lw', ':tabclose<CR>', { silent = true, desc = "Tab: Close current" })
vim.keymap.set('n', '<Leader>lq', ':tabclose<CR>', { silent = true, desc = "Tab: Close current" })
vim.keymap.set('n', '<Leader>l]', ':tabnext<CR>', { silent = true, desc = "Tab: Next" })
vim.keymap.set('n', '<Leader>l[', ':tabprev<CR>', { silent = true, desc = "Tab: Previous" })
vim.keymap.set('n', '<Leader>l1', ':tabfirst<CR>', { silent = true, desc = "Tab: Switch to 1" })
vim.keymap.set('n', '<Leader>l2', ':tabfirst<CR>:tabnext<CR>', { silent = true, desc = "Tab: Switch to 2" })
vim.keymap.set('n', '<Leader>l3', ':tabfirst<CR>:tabnext<CR>:tabnext<CR>', { silent = true, desc = "Tab: Switch to 3" })
vim.keymap.set('n', '<Leader>l4', ':tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>', { silent = true, desc = "Tab: Switch to 4" })
vim.keymap.set('n', '<Leader>l5', ':tabfirst<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>:tabnext<CR>', { silent = true, desc = "Tab: Switch to 5" })

-- Clipboard operations
vim.keymap.set('v', '<Leader>y', ':w !pbcopy<CR><CR>', { desc = "Copy current file content to system clipboard" })
vim.keymap.set('n', '<Leader>p', ':read !pbpaste<CR>', { desc = "Paste from system clipboard" })

-- Save & quit shortcuts
vim.keymap.set('n', '<Leader>s', ':w<CR>', { silent = true, desc = "Save file" })
vim.keymap.set('n', '<Leader>qq', ':q<CR>', { silent = true, desc = "Quit current buffer" })
vim.keymap.set('n', '<Leader>qa', ':qa<CR>', { silent = true, desc = "Quit all buffers" })

-- Misc
vim.keymap.set('n', '<Leader>r', ':w<CR>:!./%<CR>', { silent = true, desc = "Save and execute current file" })
vim.keymap.set('v', '<Leader>r', ':w !sh<CR>', { silent = true, desc = "Execute selected lines in shell" })

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

-- Toggle mouse support for easier copying
vim.keymap.set('n', '<Leader>m', function()
  if vim.o.mouse == 'a' then
    vim.o.mouse = ''
    vim.o.relativenumber = false
    vim.o.number = false
  else
    vim.o.mouse = 'a'
    vim.o.relativenumber = true
    vim.o.number = true
  end
end, { silent = true, desc = "Toggle mouse support" })
