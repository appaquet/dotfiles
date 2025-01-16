

-- Buffer navigation & control
require('bufdel').setup {
  quit = false,  -- don't quit on last close
}

vim.keymap.set('n', '<Leader>1', ':br!<CR>', { silent = true, desc = "Switch to buffer 1" })
vim.keymap.set('n', '<Leader>2', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 2" })
vim.keymap.set('n', '<Leader>3', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 3" })
vim.keymap.set('n', '<Leader>4', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 4" })
vim.keymap.set('n', '<Leader>5', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 5" })
vim.keymap.set('n', '<Leader>6', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 6" })
vim.keymap.set('n', '<Leader>7', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 7" })
vim.keymap.set('n', '<Leader>8', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 8" })
vim.keymap.set('n', '<Leader>9', ':br!<CR>:bn!<CR>', { silent = true, desc = "Switch to buffer 9" })
vim.keymap.set('n', '<Leader>]', ':bn!<CR>', { silent = true, desc = "Next buffer" })
vim.keymap.set('n', '<Leader>[', ':bp!<CR>', { silent = true, desc = "Previous buffer" })
vim.keymap.set('n', '<Leader>w', ':BufDel<CR>', { silent = true, desc = "Close current buffer" })
vim.keymap.set('n', '<Leader>wo', ':BufDelOthers<CR>', { silent = true, desc = "Close other buffers" })
vim.keymap.set('n', '<Leader>wa', ':BufDelAll<CR>', { silent = true, desc = "Close all buffers" })

-- Clipboard operations
vim.keymap.set('v', '<Leader>y', ':w !pbcopy<CR><CR>', { desc = "Copy current file content to system clipboard" })
vim.keymap.set('n', '<Leader>p', ':read !pbpaste<CR>', { desc = "Paste from system clipboard" })

-- Save & quit shortcuts
vim.keymap.set('n', '<D-s>', ':w<CR>', { silent = true, desc = "Save file (Cmd+S)" })
vim.keymap.set('n', '<Leader>s', ':w<CR>', { silent = true, desc = "Save file (Leader+S)" })
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
    vim.o.mouse = ''  -- Disable mouse
    vim.o.relativenumber = false  -- Disable relative line numbers
  else
    vim.o.mouse = 'a'  -- Enable mouse
    vim.o.relativenumber = true  -- Enable relative line numbers
  end
end, { silent = true, desc = "Toggle mouse support" })

-- Quickfix
vim.keymap.set("n", "<leader>xo", "<cmd>copen<cr>", { desc = "Quickfix: Open" })
vim.keymap.set("n", "<leader>xq", "<cmd>cclose<cr>", { desc = "Quickfix: Close" })
vim.keymap.set("n", "<leader>xn", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "[x", "<cmd>cprev<cr>", { desc = "Quickfix: Prev" })
vim.keymap.set("n", "]x", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "<leader>xp", "<cmd>cprev<cr>", { desc = "Quickfix: Previous" })
