-- nvim-tree
-- https://github.com/nvim-tree/nvim-tree.lua
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
})
vim.keymap.set("n", "<Leader>e", ":NvimTreeToggle<CR>zz", { desc = "Tree: Toggle" })

-- Fuzzy find in tree ('/')
-- Adapted from https://github.com/gennaro-tedesco/dotfiles/blob/master/nvim/lua/plugins/nvim_tree.lua
local api = require("nvim-tree.api")
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

					api.node.open.preview()
				end,
				desc = "fuzzy find in tree",
			},
		},
	})
end, { desc = "fuzzy find in tree" })
