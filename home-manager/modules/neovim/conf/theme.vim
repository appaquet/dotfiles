set background=dark       " Assume a dark background
let base16colorspace=256  " Access colors present in 256 colorspace

lua << EOF

-- Night owl
-- Also need to switch in ./plugin.lualine.vim
require("night-owl").setup()
vim.cmd.colorscheme("night-owl")

EOF
