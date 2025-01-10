lua << END

-- Buffer navigation & control
vim.keymap.set('n', '<Leader>1', ':br!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 1" })
vim.keymap.set('n', '<Leader>2', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 2" })
vim.keymap.set('n', '<Leader>3', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 3" })
vim.keymap.set('n', '<Leader>4', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 4" })
vim.keymap.set('n', '<Leader>5', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 5" })
vim.keymap.set('n', '<Leader>6', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 6" })
vim.keymap.set('n', '<Leader>7', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 7" })
vim.keymap.set('n', '<Leader>8', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 8" })
vim.keymap.set('n', '<Leader>9', ':br!<CR>:bn!<CR>', { noremap = true, silent = true, desc = "Switch to buffer 9" })
vim.keymap.set('n', '<Leader>]', ':bn!<CR>', { noremap = true, silent = true, desc = "Next buffer" })
vim.keymap.set('n', '<Leader>[', ':bp!<CR>', { noremap = true, silent = true, desc = "Previous buffer" })

-- Cleanly close buffers
vim.keymap.set('n', '<Leader>w', ':BufDel<CR>', { noremap = true, silent = true, desc = "Delete current buffer" })
vim.keymap.set('n', '<Leader>o', ':BufDelOthers<CR>', { noremap = true, silent = true, desc = "Delete other buffers" })

-- Execute current file or selection
vim.keymap.set('n', '<Leader>x', ':w<CR>:!./%<CR>', { noremap = true, silent = true, desc = "Save and execute current file" })
vim.keymap.set('v', '<Leader>z', ':w !sh<CR>', { noremap = true, silent = true, desc = "Execute selected lines in shell" })

-- Clipboard operations
vim.keymap.set('n', '<Leader>y', ':w !pbcopy<CR><CR>', { noremap = true, silent = true, desc = "Copy current file content to system clipboard" })
vim.keymap.set('n', '<Leader>p', ':read !pbpaste<CR>', { noremap = true, silent = true, desc = "Paste from system clipboard" })

-- Save & quit shortcuts
vim.keymap.set('n', '<D-s>', ':w<CR>', { noremap = true, silent = true, desc = "Save file (Cmd+S)" })
vim.keymap.set('n', '<Leader>s', ':w<CR>', { noremap = true, silent = true, desc = "Save file (Leader+S)" })
vim.keymap.set('n', '<Leader>qq', ':q<CR>', { noremap = true, silent = true, desc = "Quit current buffer" })
vim.keymap.set('n', '<Leader>qa', ':qa<CR>', { noremap = true, silent = true, desc = "Quit all buffers" })

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
end, { noremap = true, silent = true, desc = "Toggle mouse support" })

-- Quickfix
vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", { desc = "Quickfix: Open" })
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", { desc = "Quickfix: Close" })
vim.keymap.set("n", "<leader>qn", "<cmd>cnext<cr>", { desc = "Quickfix: Next" })
vim.keymap.set("n", "<leader>qp", "<cmd>cprev<cr>", { desc = "Quickfix: Previous" })

END
