

-----------
-- Trouble
-- https://github.com/folke/trouble.nvim
local Trouble = require("trouble")
Trouble.setup {
}

local function trouble_open()
  Trouble.open("diagnostics")
end

local function trouble_focus()
  if Trouble.is_open("diagnostics") then
    Trouble.focus()
  else
    Trouble.open("diagnostics")
  end
end

local function trouble_close()
  Trouble.close("diagnostics")
end

local function trouble_next()
  if Trouble.is_open("diagnostics") then
    Trouble.focus()
    Trouble.next()
  else
    vim.diagnostic.goto_next()
  end
end

local function trouble_prev()
  if Trouble.is_open("diagnostics") then
    Trouble.focus()
    Trouble.previous()
  else
    vim.diagnostic.goto_prev()
  end
end

-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<leader>ds', vim.diagnostic.open_float, { desc = "Diag: Open diagnostic float" })
vim.keymap.set('n', '<leader>df', vim.diagnostic.open_float, { desc = "Diag: Open diagnostic float" })
vim.keymap.set('n', '<leader>dn', trouble_next, { desc = "Diag: Go to next diagnostic" })
vim.keymap.set('n', ']d', trouble_next, { desc = "Diag: Go to next diagnostic" })
vim.keymap.set('n', '<leader>dp', trouble_prev, { desc = "Diag: Go to previous diagnostic" })
vim.keymap.set('n', '[d', trouble_prev, { desc = "Diag: Go to previous diagnostic" })
vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = "Diag: Set location list" })
vim.keymap.set('n', '<leader>do', trouble_open, { desc = "Diag: Open trouble" })
vim.keymap.set('n', '<leader>df', trouble_focus, { desc = "Diag: Focus trouble" })
vim.keymap.set('n', '<leader>dq', trouble_close, { desc = "Diag: Close trouble" })
