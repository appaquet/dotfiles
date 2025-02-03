
vim.o.background = "dark"       -- Assume a dark background
vim.g.base16colorspace = 256    -- Access colors present in 256 colorspace

-- Also need to switch in lualine config (layout.lua)
require("catppuccin").setup()
vim.cmd.colorscheme("catppuccin")
