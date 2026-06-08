local exomind_dir = vim.fn.expand("~/exomind")
local exomind_float_win = nil
local fzf = require("fzf-lua")

require("which-key").add({
	{ "<leader>m", group = "Exomind" },
	{ "<leader>mg", group = "Goto" },
	{ "<leader>mj", group = "Journal" },
	{ "<leader>mt", group = "Templates" },
})

local function is_exomind_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	return path:find(exomind_dir, 1, true) ~= nil
end

local function in_exomind_repo()
	return vim.fn.getcwd():find(exomind_dir, 1, true) ~= nil
end

-- Opens Exomind float if not already in Exomind. Optionally waits for LSP.
local function ensure_exomind_context(wait_for_lsp)
	if is_exomind_buffer() then
		return
	end

	if exomind_float_win and vim.api.nvim_win_is_valid(exomind_float_win) then
		vim.api.nvim_set_current_win(exomind_float_win)
	else
		local _, win = FloatingWindow()
		exomind_float_win = win
		vim.cmd("edit " .. exomind_dir .. "/index.md")
	end

	if wait_for_lsp then
		vim.wait(5000, function()
			return #vim.lsp.get_clients({ bufnr = 0, name = "markdown_oxide" }) > 0
		end, 50)
	end
end

local function open_exomind_file(relative_path)
	local path = exomind_dir .. "/" .. relative_path
	if vim.fn.filereadable(path) ~= 1 then
		vim.notify("Exomind file not found: " .. path, vim.log.levels.WARN)
		return
	end

	ensure_exomind_context(false)
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- fzf action that opens file in Exomind float
local function exomind_fzf_open(selected, opts)
	if exomind_float_win and vim.api.nvim_win_is_valid(exomind_float_win) then
		vim.api.nvim_set_current_win(exomind_float_win)
	end
	require("fzf-lua.actions").file_edit(selected, opts)
end

-- Template engine: replaces {{variable}} and {{variable:format}} placeholders
local templates_dir = exomind_dir .. "/templates"

local function title_from_filename(path)
	local name = vim.fn.fnamemodify(path, ":t:r")
	-- Strip date prefix patterns like "2026-02-08-" or "2026-02-08-daily"
	name = name:gsub("^%d%d%d%d%-%d%d%-%d%d%-?", "")
	if name == "" then
		name = vim.fn.fnamemodify(path, ":t:r")
	end
	-- Convert kebab-case to Title Case
	return name:gsub("(%a)([%w]*)", function(first, rest)
		return first:upper() .. rest
	end):gsub("-", " ")
end

local function render_template(template_str, ctx)
	ctx = ctx or {}
	local path = ctx.path or vim.api.nvim_buf_get_name(0)
	local filename = vim.fn.fnamemodify(path, ":t:r")
	local title = ctx.title or title_from_filename(path)

	local defaults = {
		date = function()
			return os.date("%Y-%m-%d")
		end,
		time = function()
			return os.date("%H:%M")
		end,
		title = function()
			return title
		end,
		filename = function()
			return filename
		end,
	}

	-- If ctx provides a date string, parse it into a timestamp for formatted dates
	local date_ts = nil
	if ctx.date then
		local y, m, d = ctx.date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
		if y then
			date_ts = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
		end
	end

	return (
		template_str:gsub("{{(.-)}}", function(key)
			local base, fmt = key:match("^(%w+):(.+)$")
			if base and (base == "date" or base == "time") then
				return os.date(fmt, base == "date" and date_ts or nil)
			end
			local trimmed = key:match("^%s*(.-)%s*$")
			local val = ctx[trimmed] or defaults[trimmed]
			if val == nil then
				return nil
			end
			return type(val) == "function" and val() or tostring(val)
		end)
	)
end

local function read_and_render_template(template_path, ctx)
	local lines = vim.fn.readfile(template_path)
	if not lines or #lines == 0 then
		return nil
	end
	local content = table.concat(lines, "\n")
	local rendered = render_template(content, ctx)
	return vim.split(rendered, "\n")
end

local function insert_template_at_cursor(template_path, ctx)
	local lines = read_and_render_template(template_path, ctx)
	if not lines then
		vim.notify("Empty template: " .. template_path, vim.log.levels.WARN)
		return
	end
	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)
end

local function buf_is_empty(bufnr)
	bufnr = bufnr or 0
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count > 1 then
		return false
	end
	local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
	return first_line == nil or first_line:match("^%s*$") ~= nil
end

local function canonical_daily_note_info(path)
	local daily_root = exomind_dir .. "/daily/"
	if path:sub(1, #daily_root) ~= daily_root then
		return nil
	end

	local relative_path = path:sub(#daily_root + 1)
	local y, m, d, basename = relative_path:match("^(%d%d%d%d)/(%d%d)/(%d%d)/([^.]+)%.md$")
	if not y or not m or not d or not basename then
		return nil
	end

	local date = y .. "-" .. m .. "-" .. d
	if basename ~= date .. "-daily" then
		return nil
	end

	return { date = date }
end

local function hydrate_daily_if_empty(bufnr)
	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
			return
		end

		if not buf_is_empty(bufnr) then
			return
		end

		local daily_note = canonical_daily_note_info(vim.api.nvim_buf_get_name(bufnr))
		if not daily_note then
			return
		end

		local template_path = templates_dir .. "/daily.md"
		if vim.fn.filereadable(template_path) ~= 1 then
			return
		end
		local lines = read_and_render_template(template_path, { date = daily_note.date })
		if lines then
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		end
	end)
end

-- Markdown oxide LSP configuration (code lens + :Daily command)
-- https://oxide.md/Setup+Instructions
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("MarkdownOxideConfig", {}),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or client.name ~= "markdown_oxide" then
			return
		end

		-- Code lens
		if client.server_capabilities and client.server_capabilities.codeLensProvider then
			vim.lsp.codelens.enable(true, { bufnr = ev.buf })
		end

		-- :Daily command for jumping to daily notes
		vim.api.nvim_create_user_command("Daily", function(args)
			client:request("workspace/executeCommand", { command = "jump", arguments = { args.args } }, nil, ev.buf)
		end, { desc = "Open daily note", nargs = "*" })
	end,
})

local function open_daily_with_hydrate(day_arg)
	if not in_exomind_repo() then
		ensure_exomind_context(true)
	else
		vim.wait(5000, function()
			return #vim.lsp.get_clients({ name = "markdown_oxide" }) > 0
		end, 50)
	end

	-- One-shot autocmd to hydrate after the daily note buffer loads
	local group = vim.api.nvim_create_augroup("ExomindDailyHydrate", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = "*.md",
		callback = function(args)
			if not canonical_daily_note_info(vim.api.nvim_buf_get_name(args.buf)) then
				return
			end
			vim.api.nvim_del_augroup_by_id(group)
			hydrate_daily_if_empty(args.buf)
		end,
	})

	local clients = vim.lsp.get_clients({ name = "markdown_oxide" })
	if #clients == 0 then
		vim.notify("markdown_oxide LSP not ready - try again", vim.log.levels.WARN)
		return
	end
	clients[1]:request("workspace/executeCommand",
		{ command = "jump", arguments = { day_arg } },
		nil, vim.api.nvim_get_current_buf())
end

-- Exomind keymaps
vim.keymap.set("n", "<leader>mgh", function()
	open_exomind_file("derived/home.md")
end, { silent = true, desc = "Exomind: Goto home" })

vim.keymap.set("n", "<leader>mgt", function()
	open_exomind_file("derived/todos.md")
end, { silent = true, desc = "Exomind: Goto todos" })

vim.keymap.set("n", "<leader>mjj", function()
	open_daily_with_hydrate("today")
end, { silent = true, desc = "Exomind: Today's note" })

vim.keymap.set("n", "<leader>mjp", function()
	open_daily_with_hydrate("yesterday")
end, { silent = true, desc = "Exomind: Yesterday's note" })

vim.keymap.set("n", "<leader>mjn", function()
	open_daily_with_hydrate("tomorrow")
end, { silent = true, desc = "Exomind: Tomorrow's note" })

-- File search (no LSP needed)
vim.keymap.set("n", "<leader>mf", function()
	ensure_exomind_context(false)
	fzf.files({
		cwd = exomind_dir,
		actions = { ["default"] = exomind_fzf_open },
	})
end, { desc = "Exomind: Find files" })

-- Content search (no LSP needed)
vim.keymap.set("n", "<leader>ms", function()
	ensure_exomind_context(false)
	fzf.live_grep({
		cwd = exomind_dir,
		actions = { ["default"] = exomind_fzf_open },
	})
end, { desc = "Exomind: Search content" })

-- Workspace symbols (needs LSP)
vim.keymap.set("n", "<leader>mS", function()
	ensure_exomind_context(true)
	fzf.lsp_live_workspace_symbols({
		winopts = { title = " Exomind Symbols " },
		actions = { ["default"] = exomind_fzf_open },
	})
end, { desc = "Exomind: Workspace symbols" })

-- Template picker
vim.keymap.set("n", "<leader>mt", function()
	if vim.fn.isdirectory(templates_dir) ~= 1 then
		vim.notify("Templates directory not found: " .. templates_dir, vim.log.levels.WARN)
		return
	end
	fzf.files({
		cwd = templates_dir,
		prompt = "Template> ",
		actions = {
			["default"] = function(selected)
				if not selected or #selected == 0 then
					return
				end
				local entry = require("fzf-lua.path").entry_to_file(selected[1], { cwd = templates_dir })
				insert_template_at_cursor(entry.path)
			end,
		},
	})
end, { desc = "Exomind: Insert template" })
