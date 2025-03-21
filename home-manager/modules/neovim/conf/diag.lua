

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
    --Trouble.focus()
    Trouble.next()
  else
    vim.diagnostic.goto_next()
  end
end

local function trouble_prev()
  if Trouble.is_open("diagnostics") then
    Trouble.focus()
    Trouble.prev()
  else
    vim.diagnostic.goto_prev()
  end
end

-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<leader>xs', vim.diagnostic.open_float, { desc = "Diag: Open diagnostic float" })
vim.keymap.set('n', '<leader>xf', vim.diagnostic.open_float, { desc = "Diag: Open diagnostic float" })
vim.keymap.set('n', '<leader>xn', trouble_next, { desc = "Diag: Go to next diagnostic" })
vim.keymap.set('n', ']x', trouble_next, { desc = "Diag: Go to next diagnostic" })
vim.keymap.set('n', '<leader>xp', trouble_prev, { desc = "Diag: Go to previous diagnostic" })
vim.keymap.set('n', '[x', trouble_prev, { desc = "Diag: Go to previous diagnostic" })
vim.keymap.set('n', '<leader>xl', vim.diagnostic.setloclist, { desc = "Diag: Set location list" })
vim.keymap.set('n', '<leader>xo', trouble_open, { desc = "Diag: Open trouble" })
vim.keymap.set('n', '<leader>xf', trouble_focus, { desc = "Diag: Focus trouble" })
vim.keymap.set('n', '<leader>xq', trouble_close, { desc = "Diag: Close trouble" })
