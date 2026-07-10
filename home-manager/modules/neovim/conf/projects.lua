require("which-key").add({
	{ "<leader>p", group = "Project" },
})

local fzf = require("fzf-lua")

local function get_proj_dir()
	local cwd = vim.fn.getcwd()
	for _, project_dir_name in ipairs({ "proj", "proj-adhoc" }) do
		local project_dir = cwd .. "/" .. project_dir_name
		if vim.fn.isdirectory(project_dir) == 1 then
			return project_dir
		end
	end
	return nil
end

local function open_project_file()
	local proj_dir = get_proj_dir()
	if not proj_dir then
		vim.notify("No project documentation directory found in the current working directory", vim.log.levels.WARN)
		return
	end

	local target_file = vim.fn.glob(proj_dir .. "/00-*.md", false, true)[1]
	if target_file and target_file ~= "" then
		vim.cmd("edit " .. vim.fn.fnameescape(target_file))
	else
		vim.notify("No main project document (00-*.md) found", vim.log.levels.WARN)
	end
end

local function find_project_files()
	local proj_dir = get_proj_dir()
	if not proj_dir then
		vim.notify("No project documentation directory found in the current working directory", vim.log.levels.WARN)
		return
	end
	fzf.files({ cwd = proj_dir })
end

local function grep_project_files()
	local proj_dir = get_proj_dir()
	if not proj_dir then
		vim.notify("No project documentation directory found in the current working directory", vim.log.levels.WARN)
		return
	end
	fzf.live_grep({ cwd = proj_dir })
end

vim.keymap.set("n", "<Leader>po", open_project_file, { silent = true, desc = "Project docs: open main document (00-*.md)" })
vim.keymap.set("n", "<Leader>pf", find_project_files, { silent = true, desc = "Project docs: find files" })
vim.keymap.set("n", "<Leader>fp", find_project_files, { silent = true, desc = "Project docs: find files" })
vim.keymap.set("n", "<Leader>ps", grep_project_files, { silent = true, desc = "Project docs: search" })
