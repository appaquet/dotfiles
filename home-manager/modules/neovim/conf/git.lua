
-----------------
-- General keymap
vim.keymap.set('n', '<Leader>gs', ':Git<CR>', { silent = true, desc = "Git: status" })

-----------------
-- Diffview
-- https://github.com/sindrets/diffview.nvim
require("diffview").setup {}

vim.g.main_branch_override = ''
function get_main_branch()
  if vim.g.main_branch_override ~= '' then
    return vim.g.main_branch_override
  end

  local main_branch = vim.fn.system { 'git', 'ls-remote', '--symref', 'origin', 'HEAD' }
  local main_branch = string.match(main_branch, "ref:%s+refs/heads/(%S+)")
  return main_branch
end
vim.api.nvim_command("command! -nargs=1 SetMainBranch let g:main_branch_override = <args>")

function open_diffview_main()
  local main_branch = get_main_branch()
  vim.api.nvim_command("DiffviewOpen " .. 'origin/' .. main_branch)
end

vim.keymap.set('n', '<Leader>gdo', ':DiffviewOpen<CR>', { silent = true, desc = "Git: open diff view" })
vim.keymap.set('n', '<Leader>gdm', open_diffview_main, { desc = "Git: open diff view against main branch" })
vim.keymap.set('n', '<Leader>gdb', open_diffview_main, { desc = "Git: open diff view against main branch" })
vim.keymap.set('n', '<Leader>gdq', ':DiffviewClose<CR>', { silent = true, desc = "Git: close diff view" })

-----------------
-- Git signs
-- https://github.com/lewis6991/gitsigns.nvim
require('gitsigns').setup {
  current_line_blame = true,
}

vim.keymap.set('n', '<Leader>gu', ':Gitsigns reset_hunk<CR>', { silent = true, desc = "Git: revert hunk" })
vim.keymap.set('n', '<Leader>ga', ':Gitsigns stage_hunk<CR>', { silent = true, desc = "Git: stage hunk" })
vim.keymap.set('n', ']h', ':Gitsigns nav_hunk next<CR>', { silent = true, desc = "Git: next hunk" })
vim.keymap.set('n', '[h', ':Gitsigns nav_hunk prev<CR>', { silent = true, desc = "Git: previous hunk" })
vim.keymap.set('n', '<Leader>gb', ':Gitsigns blame<CR>', { silent = true, desc = "Git: blame pane" })

function switch_gutter_base_main()
  local main_branch = get_main_branch()
  print('Switching gutter base to ' .. main_branch)
  vim.api.nvim_command("Gitsigns change_base " .. main_branch .. " global")
end

function switch_gutter_base_default()
  print('Switching gutter base to default')
  vim.api.nvim_command("Gitsigns reset_base global")
end

vim.keymap.set('n', '<Leader>ggm', switch_gutter_base_main, { silent = true, desc = "Git: switch gutter base to main branch" })
vim.keymap.set('n', '<Leader>ggb', switch_gutter_base_main, { silent = true, desc = "Git: switch gutter base to main branch" })
vim.keymap.set('n', '<Leader>ggd', switch_gutter_base_default, { silent = true, desc = "Git: switch gutter base to default" })

-----------------
-- Octo.nvim
-- https://github.com/pwntester/octo.nvim
require("octo").setup()
vim.keymap.set('n', '<Leader>ghr', ':Octo review<CR>', { silent = true, desc = "Git: github pr review" })

-------------------------
-- Gitlinker
-- Generates shareable links
-- https://github.com/ruifm/gitlinker.nvim
require("gitlinker").setup {
   mappings = "<leader>gy"
}
