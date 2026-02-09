local pkms_dir = vim.fn.expand("~/pkms")
local pkms_float_win = nil
local fzf = require("fzf-lua")

require("which-key").add({
	{ "<leader>m", group = "PKMS" },
	{ "<leader>mj", group = "Journal" },
	{ "<leader>mt", group = "Templates" },
})

local function is_pkms_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	return path:find(pkms_dir, 1, true) ~= nil
end

-- Opens PKMS float if not already in PKMS. Optionally waits for LSP.
local function ensure_pkms_context(wait_for_lsp)
	if is_pkms_buffer() then
		return
	end

	if pkms_float_win and vim.api.nvim_win_is_valid(pkms_float_win) then
		vim.api.nvim_set_current_win(pkms_float_win)
	else
		local _, win = FloatingWindow()
		pkms_float_win = win
		vim.cmd("edit " .. pkms_dir .. "/index.md")
	end

	if wait_for_lsp then
		vim.wait(2000, function()
			return #vim.lsp.get_clients({ bufnr = 0, name = "markdown_oxide" }) > 0
		end, 50)
	end
end

-- fzf action that opens file in PKMS float
local function pkms_fzf_open(selected, opts)
	if pkms_float_win and vim.api.nvim_win_is_valid(pkms_float_win) then
		vim.api.nvim_set_current_win(pkms_float_win)
	end
	require("fzf-lua.actions").file_edit(selected, opts)
end

-- Template engine: replaces {{variable}} and {{variable:format}} placeholders
local templates_dir = pkms_dir .. "/templates"

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

	return (template_str:gsub("{{(.-)}}", function(key)
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
	end))
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

local function hydrate_daily_if_empty()
	vim.schedule(function()
		if not buf_is_empty() then
			return
		end
		local template_path = templates_dir .. "/daily.md"
		if vim.fn.filereadable(template_path) ~= 1 then
			return
		end
		-- Extract date from filename (e.g., "2026-02-07-daily.md" → "2026-02-07")
		local ctx = {}
		local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		local y, m, d = fname:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
		if y then
			ctx.date = y .. "-" .. m .. "-" .. d
		end
		local lines = read_and_render_template(template_path, ctx)
		if lines then
			vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
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

		-- Code lens refresh on buffer events
		if client.server_capabilities and client.server_capabilities.codeLensProvider then
			vim.lsp.codelens.refresh({ bufnr = ev.buf })
			vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "CursorHold", "BufEnter" }, {
				buffer = ev.buf,
				callback = function()
					vim.lsp.codelens.refresh({ bufnr = ev.buf })
				end,
			})
		end

		-- :Daily command for jumping to daily notes
		vim.api.nvim_create_user_command("Daily", function(args)
			client:request("workspace/executeCommand", { command = "jump", arguments = { args.args } }, nil, ev.buf)
		end, { desc = "Open daily note", nargs = "*" })
	end,
})

local function open_daily_with_hydrate(day_arg)
	ensure_pkms_context(true)

	-- One-shot autocmd to hydrate after the daily note buffer loads
	local group = vim.api.nvim_create_augroup("PkmsDailyHydrate", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = "*/daily/*.md",
		once = true,
		callback = function()
			hydrate_daily_if_empty()
		end,
	})

	vim.cmd("Daily " .. day_arg)
end

-- Journal keymaps
vim.keymap.set("n", "<leader>mjd", function()
	open_daily_with_hydrate("today")
end, { silent = true, desc = "PKMS: Today's note" })

vim.keymap.set("n", "<leader>mjy", function()
	open_daily_with_hydrate("yesterday")
end, { silent = true, desc = "PKMS: Yesterday's note" })

vim.keymap.set("n", "<leader>mjt", function()
	open_daily_with_hydrate("tomorrow")
end, { silent = true, desc = "PKMS: Tomorrow's note" })

-- Daily note with toggle behavior
vim.keymap.set("n", "<leader>md", function()
	if pkms_float_win and vim.api.nvim_win_is_valid(pkms_float_win) then
		vim.api.nvim_win_close(pkms_float_win, true)
		pkms_float_win = nil
		return
	end

	open_daily_with_hydrate("today")
end, { desc = "PKMS: Toggle daily note" })

-- File search (no LSP needed)
vim.keymap.set("n", "<leader>mf", function()
	ensure_pkms_context(false)
	fzf.files({
		cwd = pkms_dir,
		actions = { ["default"] = pkms_fzf_open },
	})
end, { desc = "PKMS: Find files" })

-- Content search (no LSP needed)
vim.keymap.set("n", "<leader>ms", function()
	ensure_pkms_context(false)
	fzf.live_grep({
		cwd = pkms_dir,
		actions = { ["default"] = pkms_fzf_open },
	})
end, { desc = "PKMS: Search content" })

-- Workspace symbols (needs LSP)
vim.keymap.set("n", "<leader>mS", function()
	ensure_pkms_context(true)
	fzf.lsp_live_workspace_symbols({
		winopts = { title = " PKMS Symbols " },
		actions = { ["default"] = pkms_fzf_open },
	})
end, { desc = "PKMS: Workspace symbols" })

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
end, { desc = "PKMS: Insert template" })
