vim.opt.termguicolors = true -- Enable 24-bit RGB true colors
vim.o.background = "dark" -- Defaults to dark theme
vim.g.base16colorspace = 256 -- Access colors present in 256 colorspace

-- Also need to switch in lualine config (layout.lua)
-- See https://github.com/catppuccin/nvim#configuration
require("catppuccin").setup({
	flavour = "auto", -- latte, frappe, macchiato, mocha
	background = {
		light = "latte",
		dark = "mocha",
	},
	dim_inactive = {
		enabled = true, -- dims the background color of inactive window
		percentage = 0.1, -- percentage of the shade to apply to the inactive window
	},
	color_overrides = {
		mocha = {
			text = "#ffffff", -- Increase contrats a bit
		},
	},
})
vim.cmd.colorscheme("catppuccin") -- Needs to be after setup

local function toggle_theme()
	if vim.o.background == "light" then
		vim.o.background = "dark"
		vim.cmd.colorscheme("catppuccin")
	else
		vim.o.background = "light"
		vim.cmd.colorscheme("catppuccin")
	end
end
vim.keymap.set("n", "<Leader>Tt", toggle_theme, { silent = true, desc = "Toggle theme" })
