require("which-key").add({
	{ "<leader>a", group = "Agentic" },
})

local function extract_surrounding_lines(bufnr, row, window)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local before_start = math.max(1, row - window)
	local after_end = math.min(#lines, row + window)
	local before = table.concat(vim.list_slice(lines, before_start, row), "\n")
	local after = table.concat(vim.list_slice(lines, row + 1, after_end), "\n")
	return before, after
end

-- codecompanion
-- https://codecompanion.olimorris.dev/getting-started.html
require("codecompanion").setup({
	ignore_warnings = true, -- ignore future deprecation warnings from 18.0.0 (https://github.com/olimorris/codecompanion.nvim/pull/2439)
	strategies = {
		chat = {
			adapter = "copilot",
			model = "gpt-5-mini",
			tools = {},
		},
		inline = {
			adapter = "copilot",
			model = "gpt-5-mini",
		},
	},
	prompt_library = {
		["Inline prose"] = {
			strategy = "inline",
			description = "Expand a short brief into prose matching surrounding style",
			opts = {
				modes = { "n" },
				alias = "prose",
				user_prompt = true,
				placement = "add",
			},
			prompts = {
				{
					role = "system",
					content = function(context)
						return string.format(
							[[
You are continuing prose in a %s buffer. Output will be inserted on a new line directly after the user's current line.

Rules:
- Match the tone, voice, vocabulary, and sentence length of the surrounding text.
- Paraphrase and expand the user's brief into 1-3 sentences. Do not quote it verbatim.
- Output ONLY the sentence(s) to insert. No preamble, no quotes, no markdown fences, no explanation.
]],
							context.filetype
						)
					end,
				},
				{
					role = "user",
					content = "Full buffer for overall context, voice, and topic:\n\n#{buffer}",
					opts = { contains_code = false },
				},
				{
					role = "user",
					content = function(context)
						local before, after = extract_surrounding_lines(context.bufnr, context.cursor_pos[1], 30)
						return string.format(
							"Lines immediately around the insertion point. Your output will be inserted on a new line directly after the <CURSOR/> marker. Use these lines as the primary style reference.\n\n<surrounding>\n%s\n<CURSOR/>\n%s\n</surrounding>",
							before,
							after
						)
					end,
					opts = { contains_code = false },
				},
			},
		},
	},
})
vim.keymap.set(
	"v",
	"gs",
	":'<,'>CodeCompanion Fix any spelling or unclear text in this selected text. Try to keep the original meaning and intent of the text.<CR>",
	{ silent = true, desc = "CodeCompanion: Fix spelling & unclear text" }
)
vim.keymap.set(
	"v",
	"gC",
	":'<,'>CodeCompanion Add documentation to the selected text if it's missing. If it's a whole function, add proper function documentation. If it already exist, improve it. If it's code, add inline comments explaining it. If there are existing documentation, just improve it if needed. @insert_edit_into_file #buffer<CR>",
	{ silent = true, desc = "CodeCompanion: Comment code" }
)
vim.keymap.set(
	"n",
	"gA",
	"<cmd>CodeCompanion /prose<cr>",
	{ silent = true, desc = "CodeCompanion: Inline prose completion" }
)
vim.keymap.set({ "n", "v" }, "<leader>aa", ":'<,'>CodeCompanionActions<CR>", { silent = true, desc = "CodeCompanion: Actions" })
vim.keymap.set("v", "<leader>ae", function()
	vim.ui.input({ prompt = "Describe what needs to be done:" }, function(input)
		if input and input ~= "" then
			local system_prompt = "Use @insert_edit_into_file and #buffer for tool use."
			local input_escaped = vim.fn.escape(input, '"')
			local cmd = string.format(":'<,'>CodeCompanion %s %s<CR>", input_escaped, system_prompt)
			vim.cmd(cmd)
		end
	end)
end, { silent = true, desc = "CodeCompanion: Inline edit with prompt" })

-- ClaudeCode.nvim
-- https://github.com/coder/claudecode.nvim
require("claudecode").setup({})

require("which-key").add({
	{ "<leader>c", group = "Claude" },
})

vim.keymap.set("n", "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude" })
vim.keymap.set("n", "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude" })
vim.keymap.set("n", "<leader>cr", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume Claude" })
vim.keymap.set("n", "<leader>cC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continue Claude" })
vim.keymap.set("n", "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current buffer" })
vim.keymap.set("v", "<leader>cs", "<cmd>ClaudeCodeSend<cr>", { desc = "Send to Claude" })
vim.keymap.set("n", "<leader>cs", "<cmd>ClaudeCodeTreeAdd<cr>", { desc = "Add file" }) -- , ft = { "NvimTree", "neo-tree", "oil" }
vim.keymap.set("n", "<leader>ca", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })
vim.keymap.set("n", "<leader>cd", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Deny diff" })
