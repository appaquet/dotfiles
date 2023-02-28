set nocompatible        " be iMproved

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
set nu                  " Line numbers on
set smartcase           " case sensitive when uc present
set ignorecase          " case insensitive search
set hidden              " Buffer switching without saving

set autoread            " Auto reread modified file
set autoindent          " indent at the same level of the previous line
set mouse=a             " automatically enable mouse usage

set exrc                " allow project specific .vimrc
set secure              " (https://andrew.stwrt.ca/posts/project-specific-vimrc/)

"" Persists the undo across sessions
set undodir=~/.vim/undodir
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

"" fish doesn't play well with vim
"" See https://github.com/VundleVim/Vundle.vim
set shell=/bin/bash

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


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Identation preferences
""

" Defaults to spaces
setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>

" Some files forced to spaces
autocmd FileType hpp setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
autocmd FileType h setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
autocmd FileType cpp setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
autocmd FileType scala setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
autocmd FileType lua setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
autocmd FileType rb setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
autocmd FileType javascript setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>