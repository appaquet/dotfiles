# Neovim README
This is a collection of keymaps and commands for my Neovim setup. It doesn't contain only personal
keymaps, but also default/built-ins that I tend to forget.

## General keymap
* `<leader>` is space
* `<leader>qq` or `<ctrl-q>` to close current window/split
* `<leader>qa` to quit neovim
* `<leader>qs` to clear auto-session and quit neovim

## Buffers (b)
* `]b` to switch to next buffer
* `[b` to switch to previous buffer
* `<leader>b 1 through 9` to switch to buffer 1 through 9
* `<leader>b<tab>` to switch to last buffer
* `<leader>bc` to open a new empty buffer
* `<leader>bq` to close the current buffer by trying not to mess up the layout
* `<leader>bo` to close all buffers except the current one
* `<leader>ba` to close all buffers
* `<leader>bs` or `<ctrl-s>` to save current buffer

## Tabs (n)
* `]n` to switch to next tab
* `[n` to switch to previous tab
* `<leader>nc` to open a new tab
* `<leader>nq` to close current tab
* `<leader>n1 through 5` to switch to tab 1 through 5

## Layout
* `ctrl-w w` to switch between panes
* `ctrl-w r` or `ctrl-w R` to rotate panes
* `ctrl-w c` or `ctrl-w o` close current split OR others.

## Fzf (f)
* `<ctrl-p>` or `<leader>ff` fuzzy finding file names
* `<ctrl-l>` or `<leader>fs` fuzzy find in current file
* `<ctrl-g>` or `<leader>fS` fuzzy find in workspace (ripgrep)
* `<ctrl-b>` or `<leader>fb` fuzzy find through buffers
* `<leader>w` fuzzy find word under cursor in file
* `<leader>W` fuzzy find word under cursor in workspace
* `<leader>fk` fuzzy find through keymaps
* `<ctrl-\>` or `<leader>fc` fuzzy find through neovim commands
* `<leader>fr` to resume last search 
* See [fzf.lua](./home-manager/modules/neovim/conf/fzf.lua) for all keymaps

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

## Code / LSP
* `<leader>lgD` LSP: Go to declaration
* `<leader>lgd` LSP: Go to definition
* `<leader>lgt` LSP: Go to type definition

* `<leader>lli` LSP: List all implementations
* `<leader>llr` LSP: List references

* `<leader>ls` LSP: Show signature help
* `<leader>lis` LSP: Displays hover information about a symbol
* `<leader>lif` LSP: Peek function definition
* `<leader>lic` LSP: Peek class definition

* `<leader>lr` LSP: Rename
* `<leader>lca` LSP: Code action
* `<leader>lf` LSP: Format

* `<leader>lwa` LSP: Add workspace folder
* `<leader>lwr` LSP: Remove workspace folder
* `<leader>lwl` LSP: List workspace folders

## Git (g)
* `<leader>gs` show status pane
* `:Git` or `:G` or `<leader>fgs` git status
* `<leader>fgb` git branches
* `:Gdiff` to see diff
* `:Gwrite` stages current file
* `:Gcommit` to commit
* `:Glog` to show log
* `:Gblame` to show blame
* `<leader>gy` yank the current line GitHub URL

* `<leader>gu` undo hunk
* `<leader>ga` stage hunk
* `]g` next git hunk
* `[g` prev git hunk
* `<leader>ggm` switch gutter base to main branch
* `<leader>ggd` switch gutter base to default

* `<leader>gdo` diff view open
* `<leader>gdm` diff view open, diffing against main branch
* `<leader>gdq` diff view close

* `<leader>ghr` GitHub PR review

## Diagnostics (x)
* `<leader>xs` or `<leader>xf` Open diagnostic float
* `<leader>xn` or `]x` Go to next diagnostic
* `<leader>xp` or `[x` Go to previous diagnostic
* `<leader>xo` Open diagnostic panel (Trouble)
* `<leader>xq` Close diagnostic panel (Trouble)

## Quickfix (k)
* `<leader>ko` to open quickfix
* `<leader>kq` to close quickfix
* `<leader>kn` or `]k` to go to next quickfix
* `<leader>kp` or `[k` to go to prev quickfix
* `<leader>kf` to find in quickfix
* From any fzf, `<ctrl>k`, sends matches to the quickfix list

## Testing (t)
* `<leader>tc` to run nearest / under cursor
* `<leader>tdc` to debug nearest
* `<leader>tf` to run file
* `<leader>tdf` to debug file
* `<leader>tl` to run last
* `<leader>tdl` to debug last
* `<leader>tu` to stop test
* `<leader>to` to toggle output
* `<leader>tq` to close output
* `<leader>tk` to clear output

* `<leader>ts` to toggle side / summary panel, with keymaps:
  * `r` to run a test
  * `u` to stop a test
  * `i` to open a test source
  * `?` for help

## Object selection (in visual mode)
- `aX`: Select around object X  
- `iX`: Select inside object X  
  *(X = (p)arameter, (f)unction, (c)lass, (s)cope)*

## Object movements
- `]X`: Next start of X
- `[X`: Previous start of X
- `]X`, `[X`: With capital letters → go to end
  *(X = (m)ethod/function, (c)lass, l(o)op, (s)cope, (z)fold, con(d)itional, (b)lock)*

## Object manipulations
- `<leader>Sp`: Swap with next parameter
- `<leader>Sf`: Swap with next function
- `<leader>SP`: Swap with previous parameter
- `<leader>SF`: Swap with previous function

## Text manipulation
* `<leader>cc` to comment line (via nerdcommenter)
* `<leader>cu` to uncomment line (via nerdcommenter)
* `gw` to format text (in visual)
* `gu` to lowercase text (in visual)
* `gU` to upercase text (in visual)
* `g~` to toggle casing (in visual)

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
* `<leader>ym` to toggle mouse support (useful to allow select + copy)
* `<leader>y` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
* `<leader>yp` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util
* `<leader>W` to toggle line wrap
* `z=` to see spelling suggestions for word under cursor (built-in)
* `zz` to center cursor in the middle of the screen

## Commands
* `Rename <file name>` to rename current file
* `New <file name>` to create a file in current buffer dir
* `Delete` to delete current file

