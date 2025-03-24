
-- General keymap
vim.keymap.set('n', '<Leader>gs', ':Git<CR>', { silent = true, desc = "Git: status" })

-- Diffview
-- https://github.com/sindrets/diffview.nvim
require("diffview").setup {}

function get_main_branch()
  local main_branch = vim.fn.system { 'git', 'ls-remote', '--symref', 'origin', 'HEAD' }
  local main_branch = string.match(main_branch, "ref:%s+refs/heads/(%S+)")
  return main_branch
end

function open_diffview_main()
  local main_branch = get_main_branch()
  vim.api.nvim_command("DiffviewOpen " .. 'origin/' .. main_branch)
end

vim.keymap.set('n', '<Leader>gdo', ':DiffviewOpen<CR>', { silent = true, desc = "Git: open diff view" })
vim.keymap.set('n', '<Leader>gdm', open_diffview_main, { desc = "Git: open diff view against main branch" })
vim.keymap.set('n', '<Leader>gdq', ':DiffviewClose<CR>', { silent = true, desc = "Git: close diff view" })

-- Git gutter
-- https://github.com/airblade/vim-gitgutter
vim.keymap.set('n', '<Leader>gu', ':GitGutterUndoHunk<CR>', { silent = true, desc = "Git: revert hunk" })
vim.keymap.set('n', '<Leader>ga', ':GitGutterStageHunk<CR>', { silent = true, desc = "Git: stage hunk" })
vim.keymap.set('n', ']h', ':GitGutterNextHunk<CR>', { silent = true, desc = "Git: next hunk" })
vim.keymap.set('n', '[h', ':GitGutterPrevHunk<CR>', { silent = true, desc = "Git: previous hunk" })

function switch_gutter_base_main()
  local main_branch = get_main_branch()
  print('Switching gutter base to ' .. main_branch)
  vim.api.nvim_command("let g:gitgutter_diff_base = '" .. main_branch .. "'")
  vim.api.nvim_command("GitGutter")
end

function switch_gutter_base_default()
  print('Switching gutter base to default')
  vim.api.nvim_command("let g:gitgutter_diff_base = ''")
  vim.api.nvim_command("GitGutter")
end

vim.keymap.set('n', '<Leader>ggm', switch_gutter_base_main, { silent = true, desc = "Git: switch gutter base to main branch" })
vim.keymap.set('n', '<Leader>ggd', switch_gutter_base_default, { silent = true, desc = "Git: switch gutter base to default" })
