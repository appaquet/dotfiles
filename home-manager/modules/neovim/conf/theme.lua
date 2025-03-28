vim.opt.termguicolors = true -- Enable 24-bit RGB true colors
vim.o.background = "dark" -- Assume a dark background
vim.g.base16colorspace = 256 -- Access colors present in 256 colorspace

-- Also need to switch in lualine config (layout.lua)
-- See https://github.com/catppuccin/nvim#configuration
require("catppuccin").setup({
	flavour = "mocha",
	dim_inactive = {
		enabled = true, -- dims the background color of inactive window
		percentage = 0.20, -- percentage of the shade to apply to the inactive window
	},
	color_overrides = {
		mocha = {
			text = "#ffffff", -- Increase contrats a bit
		},
	},
})
vim.cmd.colorscheme("catppuccin") -- Needs to be after setup
