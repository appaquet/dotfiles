"" Various buffers mapping
map <D-1> :br!<CR>
map <Leader>1 :br!<CR>
map <D-2> :br!<CR>:bn!<CR>
map <Leader>2 :br!<CR>:bn!<CR>
map <D-3> :br!<CR>:bn! 2<CR>
map <Leader>3 :br!<CR>:bn! 2<CR>
map <D-4> :br!<CR>:bn! 3<CR>
map <Leader>4 :br!<CR>:bn! 3<CR>
map <D-5> :br!<CR>:bn! 4<CR>
map <Leader>5 :br!<CR>:bn! 4<CR>
map <D-6> :br!<CR>:bn! 5<CR>
map <Leader>6 :br!<CR>:bn! 5<CR>
map <D-7> :br!<CR>:bn! 6<CR>
map <Leader>7 :br!<CR>:bn! 6<CR>
map <D-8> :br!<CR>:bn! 7<CR>
map <Leader>8 :br!<CR>:bn! 7<CR>
map <D-9> :br!<CR>:bn! 8<CR>
map <Leader>9 :br!<CR>:bn! 8<CR>
map <Leader>] :bn!<CR>
map <Leader>[ :bp!<CR>
map <Leader>x :w<CR>:!./%<CR>
map <Leader>z :'<,'>w !sh<CR>
map <Leader>y :w !pbcopy<CR><CR>
map <Leader>p :read !pbpaste<CR>
map <D-x> :w<CR>:!./%<CR>
map <D-s> :w<CR>
map <Leader>s :w<CR>
map <D-r>r :!./rsync.sh<CR>
map <Leader>r :!./rsync.sh<CR>
map <D-q> :q<CR>
map <Leader>q :q<CR>

" Cleanly close buffer
map <D-0> :Bclose<creating>
nmap <leader>w :Bclose<CR>

" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null
cmap wq wqa
cmap qw wqq

" Ctrp-p via fzf
map <C-p> :Files<CR>
map <C-f> :Rg<CR>

" Toggle mouse for copy
nmap <Leader>m :call ToggleMouse()<CR>
function! ToggleMouse()
    " check if mouse is enabled
    if &mouse == 'a'
        " disable mouse
        set mouse=
        set nonumber
    else
        " enable mouse everywhere
        set mouse=a
        set number
    endif
endfunc

" Allow switching by doing <leader><tab>
nmap <leader><tab> :call SwitchTab()<CR>
function! SwitchTab()
  if (&l:expandtab)
    echo "Switched to Tabs"
    setlocal noexpandtab shiftwidth=4 tabstop=4 cino=N-s<CR>
  else
    echo "Switched to Spaces"
    setlocal expandtab shiftwidth=2 tabstop=2 cino=N-s<CR>
  endif
endfunction