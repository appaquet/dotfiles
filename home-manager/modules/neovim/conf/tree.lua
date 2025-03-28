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
