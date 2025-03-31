-- nvim-tree
-- https://github.com/nvim-tree/nvim-tree.lua
local function on_attach(bufnr)
	local api = require("nvim-tree.api")

	local function opts(desc)
		return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
	end

	-- default mappings
	api.config.mappings.default_on_attach(bufnr)

	-- Fuzzy find in tree ('/')
	-- Adapted from https://github.com/gennaro-tedesco/dotfiles/blob/master/nvim/lua/plugins/nvim_tree.lua
	vim.keymap.set("n", "/", function()
		local fzf = require("fzf-lua")
		fzf.fzf_exec("fd -H -t f -E '.git/'", {
			prompt = ":",
			actions = {
				["default"] = {
					fn = function(selected)
						if selected[1]:find("^%.") ~= nil then
							api.tree.toggle_hidden_filter()
						end

						api.tree.find_file(selected[1])

						---@diagnostic disable-next-line: missing-parameter
						api.node.open.preview()
					end,
					desc = "fuzzy find in tree",
				},
			},
		})
	end, opts("fuzzy find in tree"))
end

require("nvim-tree").setup({
	update_focused_file = {
		enable = true,
	},
	diagnostics = {
		enable = true,
		show_on_dirs = true,
	},
	actions = {
		open_file = {
			resize_window = false, -- Prevent resizing tree on opening file
			quit_on_open = true, -- Close tree when opening a file
		},
	},
	view = {
		preserve_window_proportions = false,
	},
	on_attach = on_attach,
})
vim.keymap.set("n", "<Leader>e", ":NvimTreeToggle<CR>zz", { desc = "Tree: Toggle", silent = true })
