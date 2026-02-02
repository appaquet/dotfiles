vim.keymap.set("i", "<C-e>", "<Nop>")

require("which-key").setup({
	triggers = {
		{ "<auto>", mode = "nxsoi" },
	},
})

require("which-key").add({
	{ "<C-e>", group = "Template", mode = { "n", "i" } },
	{ "<C-e>t", group = "Todo", mode = { "n", "i" } },
	{ "<C-e>c", group = "Comment tag", mode = { "n", "i" } },
	{ "<C-e>h", group = "Heading", mode = { "n", "i" } },
})

local function insert_line(text)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, row, row, false, { text })
	vim.api.nvim_win_set_cursor(0, { row + 1, #text })
	vim.cmd("startinsert!")
end

local function comment_prefix()
	local cs = vim.bo.commentstring
	if cs == "" then
		return "// "
	end
	-- commentstring is like "// %s" or "# %s" or "-- %s"
	local prefix = cs:gsub("%%s", ""):gsub("%s*$", "")
	return prefix .. " "
end

local function insert_comment_tag(tag)
	insert_line(comment_prefix() .. tag .. ": ")
end

local function todo_insert()
	insert_line("- [ ] ")
end

local function todo_set_state(state)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
	local new_line = line:gsub("%[[ ~x]%]", "[" .. state .. "]", 1)
	if new_line ~= line then
		vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
	end
end

-- Todo
vim.keymap.set({ "n", "i" }, "<C-e>ti", todo_insert, { silent = true, desc = "Todo: Insert" })
vim.keymap.set({ "n", "i" }, "<C-e>td", function()
	todo_set_state("x")
end, { silent = true, desc = "Todo: Done" })
vim.keymap.set({ "n", "i" }, "<C-e>tp", function()
	todo_set_state("~")
end, { silent = true, desc = "Todo: In progress" })
vim.keymap.set({ "n", "i" }, "<C-e>tu", function()
	todo_set_state(" ")
end, { silent = true, desc = "Todo: Undo" })

-- Comment tags
vim.keymap.set({ "n", "i" }, "<C-e>cr", function()
	insert_comment_tag("REVIEW")
end, { silent = true, desc = "Comment: REVIEW" })
vim.keymap.set({ "n", "i" }, "<C-e>ct", function()
	insert_comment_tag("TODO")
end, { silent = true, desc = "Comment: TODO" })
vim.keymap.set({ "n", "i" }, "<C-e>cf", function()
	insert_comment_tag("FIXME")
end, { silent = true, desc = "Comment: FIXME" })
vim.keymap.set({ "n", "i" }, "<C-e>cn", function()
	insert_comment_tag("NOTE")
end, { silent = true, desc = "Comment: NOTE" })

-- Markdown
vim.keymap.set({ "n", "i" }, "<C-e>b", function()
	insert_line("- ")
end, { silent = true, desc = "Bullet" })
vim.keymap.set({ "n", "i" }, "<C-e>h1", function()
	insert_line("# ")
end, { silent = true, desc = "Heading 1" })
vim.keymap.set({ "n", "i" }, "<C-e>h2", function()
	insert_line("## ")
end, { silent = true, desc = "Heading 2" })
vim.keymap.set({ "n", "i" }, "<C-e>h3", function()
	insert_line("### ")
end, { silent = true, desc = "Heading 3" })
vim.keymap.set({ "n", "i" }, "<C-e>h4", function()
	insert_line("#### ")
end, { silent = true, desc = "Heading 4" })
