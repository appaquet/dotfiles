
-- https://github.com/sindrets/diffview.nvim
require("diffview").setup {}

function open_diffview_base()
  local main_branch = vim.fn.system { 'git', 'ls-remote', '--symref', 'origin', 'HEAD' }
  local main_branch = string.match(main_branch, 'refs/heads/(.*)')
  vim.api.nvim_command("DiffviewOpen " .. main_branch)
end

vim.keymap.set('n', '<Leader>gs', ':Git<CR>', { silent = true, desc = "Git: status" })
vim.keymap.set('n', '<Leader>gu', ':GitGutterUndoHunk<CR>', { silent = true, desc = "Git: revert hunk" })
vim.keymap.set('n', '<Leader>ga', ':GitGutterStageHunk<CR>', { silent = true, desc = "Git: stage hunk" })
vim.keymap.set('n', '<Leader>gdo', ':DiffviewOpen<CR>', { silent = true, desc = "Git: open diff view" })
vim.keymap.set('n', '<Leader>gdb', open_diffview_base, { desc = "Git: open diff view" })
vim.keymap.set('n', '<Leader>gdq', ':DiffviewClose<CR>', { silent = true, desc = "Git: close diff view" })
