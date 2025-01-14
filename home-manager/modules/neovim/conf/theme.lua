
vim.o.background = "dark"       -- Assume a dark background
vim.g.base16colorspace = 256    -- Access colors present in 256 colorspace

-- Night owl
-- Also need to switch in ./plugin.lualine.vim
require("night-owl").setup()
vim.cmd.colorscheme("night-owl")
