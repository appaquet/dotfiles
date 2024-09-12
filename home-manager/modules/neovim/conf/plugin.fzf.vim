" https://github.com/junegunn/fzf.vim
map <C-p> :Files<CR>
map <C-l> :History<CR>
map <C-f> :Rg<CR>
let $FZF_DEFAULT_COMMAND="rg --files --hidden -g '!.git'"
