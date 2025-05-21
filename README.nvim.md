# Neovim README
This is a collection of keymaps and commands for my Neovim setup. It doesn't contain only personal
keymaps, but also default/built-ins that I tend to forget.

## General keymap
* `<leader>` is space
* `<leader>qq` or `<ctrl-q>` to close current window/split
* `<leader>qa` to quit neovim
* `<leader>qs` to clear auto-session and quit neovim

## Buffers (b)
* `<leader> 1 through 9` to switch to buffer 1 through 9
* `]b` to switch to next buffer
* `[b` to switch to previous buffer
* `<leader>b<tab>` to switch to last buffer
* `<leader>bh` or `<leader>bl` to move tab to the left/right
* `<leader>bc` to open a new empty buffer
* `<leader>bp` to pin a buffer (stays left)
* `<leader>bu` to undo changes (reload from disk)
* `<leader>bq` or `<leader>bqq` to close the current buffer by trying not to mess up the layout
* `<leader>bqo` to close all buffers except the current one
* `<leader>bqa` to close all buffers
* `<leader>bqh` or `<leader>bql` to close all buffers to the left/right
* `<leader>w`, `<leader>ww` to save current buffer
* `<leader>wa` to save all buffers

## Tabs (n)
* `<leader>nc` to open a new tab
* `]n` to switch to next tab
* `[n` to switch to previous tab
* `<leader>n1 through 5` to switch to tab 1 through 5
* `<leader>nq` to close current tab
* `<leader>n<tab>` to switch to last tab

## Windows
* `ctrl-w w` to swap left and right window buffers
* `ctrl-w r` or `ctrl-w R` to rotate panes
* `ctrl-w c` or `ctrl-w o` close current split OR others.
* `ctrl-w z` to toggle zen mode
* `ctrl-w pl` to pop current buffer to right window and navigate back
* `ctrl-w pf` to pop current buffer to a floating window and navigate back
* `ctrl-w ]` to increase window width
* `ctrl-w [` to decrease window width
* `ctrl-w m` to set window width to 80% of screen

## Fzf (f)
* `<ctrl-p>` or `<leader>ff` fuzzy finding file names (can also be used in tree)
* `<ctrl-l>` or `<leader>fs` fuzzy find content in current file
* `<ctrl-g>` or `<leader>fS` fuzzy find content in workspace (can also be used in tree)
* `<ctrl-b>` or `<leader>fb` fuzzy find through buffers
* `<ctrl-s>` or `<leader>fls` fuzzy find through document symbols
* `<ctrl-n>` (`n`) or `<leader>fn` fuzzy find through tabs
* `<leader>w` fuzzy find word under cursor in file
* `<leader>W` fuzzy find word under cursor in workspace
* `<leader>fk` fuzzy find through keymaps
* `<leader>fc` fuzzy find through neovim commands
* `<leader>fr` to resume last search 
* Inside fzf
  * `<ctrl-k>` to send matches to quickfix list
  * `<ctrl-v>` to open selection in vertical split
  * `<ctrl-s>` to open selection in horizontal split
  * `<ctrl-i>` to toggle ignored files
  * `<ctrl-h>` to toggle hidden files
  * `<ctrl-d>` or `<ctrl-u>` to page through results
  * `<shift-up>` or `<shift-down>` to page through preview
* See [fzf.lua](/home-manager/modules/neovim/conf/fzf.lua) for all keymaps
* Insert-mode completions
  * `<ctrl-x><ctrl-f>` to fuzzy complete files/paths

### Keymap inside window
* `<ctrl>k`, sends matches to the quickfix list
* `<ctrl>v`, open in vertical split
* `<ctrl>s`, open in horizontal split
* `<ctrl>t`, open in new tab

## Nvim tree
* `<leader>e` to toggle filetree
* In tree
  * `g?` to show help
  * `<ctrl>]` to CD into directory
  * `-` go up one directory
  * `<ctrl>v` Open in vertical split
  * `<ctrl>x` Open in horizontal split
  * `I` Toggle hidden files
  * `r` Rename file
  * `d` Delete file
  * `a` Add file or directory if it ends with `/`
  * `c`, `x`, `v` to copy, cut, paste files
  * `f` to find file, `F` to clear
  * `q` to close tree
  * `E` to expand all, `W` to collapse
  * `/` to fuzzy find file

## LSP
* `<leader>lgD` LSP: Go to declaration
* `<leader>lgd` or `gd` LSP: Go to definition
* `<leader>lgt` or `gt` LSP: Go to type definition
* `<leader>lli` or `gri` LSP: List all implementations
* `<leader>llr` or `grr` LSP: List references
* `<leader>lii` LSP: Displays hover information about a symbol
* `<leader>lis` LSP: Show signature help
* `<leader>lif` LSP: Peek function definition
* `<leader>lic` LSP: Peek class definition
* `<leader>Ti` LSP: Toggle inlay line hints
* `<leader>lr` or `grn` LSP: Rename
* `<leader>lca` or `<ctrl-l>` (in insert|visual) or `gra` LSP: Code action
* `<leader>lwa` LSP: Add workspace folder
* `<leader>lwr` LSP: Remove workspace folder
* `<leader>lwl` LSP: List workspace folders


## Git (g)
* `<leader>gs` to show git status
* `:Git` or `:G` or `<leader>fgs` to show git status
* `<leader>fgb` to list git branches
* `:Gdiff` to see diff
* `:Gwrite` to stage the current file
* `:Gcommit` to commit changes
* `:Glog` to show git log
* `:Gblame` to show blame
* `<leader>gy` to yank the current line GitHub URL
* `<leader>gu` to revert hunk
* `<leader>ga` to stage hunk
* `]g` to navigate to the next git hunk
* `[g` to navigate to the previous git hunk
* `<leader>ggm` to switch gutter base against main branch
* `<leader>ggp` to switch gutter base against previous branch
* `<leader>ggw` to switch gutter base to working directory
* `<leader>gdo` to open diff view
* `<leader>gdm` to open diff view against main branch
* `<leader>gdp` to open diff view against previous branch
* `<leader>gdq` to close diff view
* `<leader>gdb` to open buffer diff

### PR review
See [https://github.com/pwntester/octo.nvim/blob/03059cf4d694e2b3065136f074b42ee98ff8e4b2/lua/octo/config.lua#L238]
* `<leader>gpo` to open PR review mode
* `<leader>gpq` to close PR review mode
* `<leader>gpl` to list PRs
* Files 
  * `]q` and `[q` to navigate between files
  * `]Q` and `[Q` to navigate first and last files
  * `<leader>space` to toggle file as reviewed
  * `gf` to open file (unfortunately not in new tab)
* Comments
  * `<leader>gpc` to review comments
  * `<leader>ca` to add a comment (save + unfocus window to submit)
  * `<leader>cd` to delete a comment (in comment window)
  * `<leader>sa` to add line suggestion
  * `<leader>r` to add reaction 
  * `]c` and `[c` to navigate between comments
* Review
  * `<leader>gps` to submit review
  * `<C-m>` to submit with comment
  * `<C-a>` to approve
  * `<C-r>` to request change

## Diagnostics (x)
* `<leader>xs` or `<leader>xf` Open diagnostic float
* `<leader>xo` Open diagnostic panel (Trouble)
* `<leader>xq` Close diagnostic panel (Trouble)
* `]x` Go to next diagnostic (in file)
* `[x` Go to previous diagnostic (in file)
* `]X` Go to next diagnostic (global)
* `[X` Go to previous diagnostic (global)
* In diagnostic panel
  * `s` to toggle between severty levels

## Quickfix (k)
* `<leader>ko` to open quickfix
* `<leader>kq` to close quickfix
* `<leader>kc` to clear quickfix
* `<leader>kn` or `]k` to go to next quickfix
* `<leader>kp` or `[k` to go to prev quickfix
* `<leader>kf` to find in quickfix
* From any fzf, `<ctrl>k`, sends matches to the quickfix list

## Testing (t)
* `<leader>tc` to run nearest / under cursor
* `<leader>tdc` to debug nearest
* `<leader>tf` to run file
* `<leader>tdf` to debug file
* `<leader>tp` to run package/directory
* `<leader>tdp` to debug package/directory
* `<leader>tl` to run last
* `<leader>tdl` to debug last
* `<leader>tu` to stop test
* `<leader>to` to output pane
* `<leader>tq` to close output

* `<leader>ts` to toggle side / summary panel, with keymaps:
  * `r` to run a test
  * `u` to stop a test
  * `i` to open a test source
  * `?` for help

## Debugging (d)
* `<leader>db` to toggle breakpoint
* `<leader>dc` to start/continue debugging
* `<leader>do` to step over
* `<leader>dI` to step into
* `<leader>dO` to step out
* `<leader>dj` to move down in the stack trace
* `<leader>dk` to move up in the stack trace
* `<leader>dp` to pause execution
* `<leader>dt` to terminate the debugging session
* `<leader>dr` to restart the debugging session
* `<leader>de` to toggle the REPL
* `<leader>dl` to run last
* `<leader>dC` to run to cursor
* `<leader>du` to open the DAP UI
* `<leader>dq` to terminate & quit the DAP UI

## Object selection (in visual mode)
- `aX`: Select around object X  
- `iX`: Select inside object X  
  *(X = (p)arameter, (f)unction, (c)lass, (s)cope)*

## Object movements
- `]X`: Next start of X
- `[X`: Previous start of X
- `]X`, `[X`: With capital letters → go to end
  *(X = (m)ethod/function, (c)lass, l(o)op, (z)fold, con(d)itional, (b)lock)*

## Object manipulations
- `<leader>Sp`: Swap with next parameter
- `<leader>Sf`: Swap with next function
- `<leader>SP`: Swap with previous parameter
- `<leader>SF`: Swap with previous function

## Text/code manipulation
* `gw` to format text (using vim, in visual)
* `gc` to comment text (in visual)
* `gu` to lowercase text (in visual)
* `gU` to upercase text (in visual)
* `g~` to toggle casing (in visual)
* `g;` and `g,` to navigate through last edits
* `<ctrl-n>` to start multicursor edit
  * A keymap helper will show up with the available keymaps
  * `n`, `N` to go to next/prev match
  * `q` to skip current match
  * `c` to change matches
  * `d` to delete matches
  * `a` to append after matches

## Folding
* `zm` to fold more
* `zM` to fold all
* `zr` to unfold more
* `zR` to unfold all
* `za` to toggle fold under cursor

## Marks
* `m[a-z0-9A-Z]` to set mark
* `'[a-z0-9A-Z]` to list (which-key) and go to mark

## Recording & registers
* `q[a-z0-9A-Z]` to start recording
* `q` to stop recording
* `@[a-z0-9A-Z]` to play macro (can be prefixed with number)
* `.` to replay last action (or macro)
* `"[a-z0-9A-Z]` to yank to register
* `"[a-z0-9A-Z]p` to list (which-key) and paste from register

## Misc
* `<leader>r` to execute current buffer in a shell (normal mode)
* `<leader>r` to execute current visual selection in a shell (visual mode)
* `<leader>Tm` to toggle mouse support (useful to allow select + copy)
* `<leader>Tn` to toggle line numbers
* `<leader>yy` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
* `<leader>yp` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util
* `<leader>yc` to yank the current line and comment the previous one
* `<leader>Tw` to toggle line wrap
* `<leader>Tt` to toggle theme between light and dark
* `zz` to center cursor in the middle of the screen
* `<ctrl-/>` to clear search highlights

## Spelling
* `<leader>Ts` to toggle spell checking
* `]s` or `[s` to go to next/prev spelling error
* `z=` to see spelling suggestions for word under cursor (built-in)
* `zg` to add word under cursor to spelling dictionary
* `zw` to remove word under cursor from spelling dictionary

