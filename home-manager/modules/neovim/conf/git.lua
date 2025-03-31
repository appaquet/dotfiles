-- Diffview
-- https://github.com/sindrets/diffview.nvim
require("diffview").setup({})

vim.g.main_branch_override = ""
local function git_main_branch()
	if vim.g.main_branch_override ~= "" then
		return vim.g.main_branch_override
	end
	return vim.fn.system("git-main-branch")
end
vim.api.nvim_command("command! -nargs=1 SetMainBranch let g:main_branch_override = <args>")

local function git_prev_branch()
	-- Returns the previous branch in the PR branch
	-- Could be the main branch if the PR is on top of main
	return vim.fn.system("git-prev-branch")
end

local function open_diffview_main()
	local main_branch = git_main_branch()
	vim.api.nvim_command("DiffviewOpen " .. "origin/" .. main_branch)
	vim.notify("Diffing against origin/" .. main_branch)
end

local function open_diffview_prev()
	local prev_branch = git_prev_branch()
	vim.api.nvim_command("DiffviewOpen " .. prev_branch)
	vim.notify("Diffing against " .. prev_branch)
end

vim.keymap.set("n", "<Leader>gdw", ":DiffviewOpen<CR>", { silent = true, desc = "Git: open diff view against working dir" })
vim.keymap.set("n", "<Leader>gdm", open_diffview_main, { desc = "Git: open diff view against main branch" })
vim.keymap.set("n", "<Leader>gdp", open_diffview_prev, { desc = "Git: open diff view against previous branch" })
vim.keymap.set("n", "<Leader>gdq", ":DiffviewClose<CR>", { silent = true, desc = "Git: close diff view" })

-- Git signs
-- https://github.com/lewis6991/gitsigns.nvim
require("gitsigns").setup({
	current_line_blame = true,
})

vim.keymap.set("n", "<Leader>gu", ":Gitsigns reset_hunk<CR>", { silent = true, desc = "Git: revert hunk" })
vim.keymap.set("n", "<Leader>ga", ":Gitsigns stage_hunk<CR>", { silent = true, desc = "Git: stage hunk" })
vim.keymap.set("n", "]g", ":Gitsigns nav_hunk next<CR>", { silent = true, desc = "Git: next hunk" })
vim.keymap.set("n", "[g", ":Gitsigns nav_hunk prev<CR>", { silent = true, desc = "Git: previous hunk" })
vim.keymap.set("n", "<Leader>gb", ":Gitsigns blame<CR>", { silent = true, desc = "Git: blame pane" })
vim.keymap.set("n", "<Leader>gdb", ":Gitsigns diffthis<CR>", { silent = true, desc = "Git: open buffer diff" })

local function switch_gutter_base_main()
	local main_branch = git_main_branch()
	vim.api.nvim_command("Gitsigns change_base " .. main_branch .. " global")
	vim.notify("Switching git gutter against " .. main_branch)
end
local function switch_gutter_base_prev()
	local prev_branch = git_prev_branch()
	vim.api.nvim_command("Gitsigns change_base " .. prev_branch .. " global")
	vim.notify("Switching git gutter against " .. prev_branch)
end
local function switch_gutter_base_default()
	vim.api.nvim_command("Gitsigns reset_base global")
	vim.notify("Switching git gutter to default")
end

vim.keymap.set("n", "<Leader>ggm", switch_gutter_base_main, { silent = true, desc = "Git: switch gutter base gainst main branch" })
vim.keymap.set("n", "<Leader>ggp", switch_gutter_base_prev, { silent = true, desc = "Git: switch gutter base against previous branch" })
vim.keymap.set("n", "<Leader>ggw", switch_gutter_base_default, { silent = true, desc = "Git: switch gutter base to working dir" })

-- Octo.nvim
-- https://github.com/pwntester/octo.nvim
require("octo").setup()
vim.keymap.set("n", "<Leader>ghr", ":Octo review<CR>", { silent = true, desc = "Git: github pr review" })

-- Gitlinker
-- Generates shareable links
-- https://github.com/ruifm/gitlinker.nvim
require("gitlinker").setup({
	mappings = "<leader>gy",
})

-- General keymap
vim.keymap.set("n", "<Leader>gs", ":Git<CR>", { silent = true, desc = "Git: status" })
