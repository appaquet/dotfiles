set background=dark     " Assume a dark background
let base16colorspace=256  " Access colors present in 256 colorspace

lua << EOF

-- See https://github.com/RRethy/nvim-base16
-- List of themes: https://github.com/chriskempson/base16
vim.cmd('colorscheme base16-tomorrow-night')

EOF
