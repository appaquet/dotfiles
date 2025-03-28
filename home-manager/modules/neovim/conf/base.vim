
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
set formatoptions-=t    " don't auto-wrap text (but comments will still auto-wrap (+c))

" Persists the undo across sessions
set undodir=~/.config/nvim/undodir
set undofile

" Defaults to space indentation
set expandtab shiftwidth=2 tabstop=2
