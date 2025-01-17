
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Misc settings
""

set ruler               " show the ruler
set showmatch           " show matching brackets/parenthesis
set incsearch           " find as you type search
set hlsearch            " highlight search terms
set relativenumber      " relative line numbers
set number              " show current absolute number instead of 0
set smartcase           " case sensitive when uc present
set ignorecase          " case insensitive search
set hidden              " buffer switching without saving

set autoread            " auto reread modified file
set autoindent          " indent at the same level of the previous line
set timeoutlen=500      " time to wait for a key code sequence to complete

set textwidth=100       " max line length, because we aren't on a mainframe anymore

"" Persists the undo across sessions
set undodir=~/.config/nvim/undodir
set undofile

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
