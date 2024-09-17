
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Misc settings
""
syntax on
filetype plugin on

set backspace=2
set ruler               " show the ruler
set showmatch           " show matching brackets/parenthesis
set incsearch           " find as you type search
set hlsearch            " highlight search terms
set relativenumber      " relative line numbers
set smartcase           " case sensitive when uc present
set ignorecase          " case insensitive search
set hidden              " buffer switching without saving

set autoread            " auto reread modified file
set autoindent          " indent at the same level of the previous line
set mouse=a             " automatically enable mouse usage

set exrc                " allow project specific .vimrc
set secure              " (https://andrew.stwrt.ca/posts/project-specific-vimrc/)

"" Persists the undo across sessions
set undodir=~/.config/nvim/undodir
set undofile

"" Fixes slow escape in tmux
"" https://www.reddit.com/r/neovim/comments/35h1g1/neovim_slow_to_respond_after_esc/
if !has('gui_running')
  set ttimeoutlen=10
  augroup FastEscape
    autocmd!
    au InsertEnter * set timeoutlen=0
    au InsertLeave * set timeoutlen=1000
  augroup END
endif

" Defaults to space indentation
set expandtab shiftwidth=2 tabstop=2

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Util functions
""

" Allow creating a file in current buffer's directory by using "E" or "New"
fun! NewCfd( arg )
  execute 'e %:p:h/' . a:arg
endfunction
command! -nargs=* E call NewCfd( '<args>' )
command! -nargs=* New call NewCfd( '<args>' )

" Delete current file. You need to close it after.
fun! DeleteCfd( arg )
  let l:curfile = expand("%")
  silent exe ":!rm ". l:curfile
  silent exe "bwipe! " . l:curfile
endfunction
command! -nargs=* Delete call DeleteCfd( '<args>' )
