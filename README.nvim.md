# Neovim README

## General keymap
  * `<leader>` is `\` (backslash)
  * `<leader>qq` to close current pane
  * `<leader>qa` to quit vim

## Buffers
* `<leader> 1 through 9` to switch to buffer 1 through 9
  * `<leader>]` to switch to next buffer
  * `<leader>[` to switch to previous buffer
* `<leader><tab>` to switch to last buffer
  * `<leader>s` to save current buffer
  * `<leader>w` to close the current buffer by trying not to mess up the layout
  * `<leader>wo` to close all buffers except the current one
  * `<leader>wa` to close all buffers

## Tabs (l)
  * `]l` to switch to next tab
  * `[l` to switch to previous tab
  * `<leader>lw` or `<leader>lq` to close current tab
  * `<leader>ln` to open a new tab
* `<leader>l1 through 5` to switch to tab 1 through 5

## Fzf
  * `<ctrl>p` or `<leader>ff` fuzzy finding file names
  * `<ctrl-l>` or `<leader>fs` fuzzy find in current file
  * `<ctrl-g>` or `<leader>fS` fuzzy find in workspace (ripgrep)
  * `<ctrl-b>` or `<leader>fb` fuzzy find through buffers
  * `<ctrl-\>` fuzzy find through neovim commands
  * `<leader>fk` fuzzy find through keymaps
  * When open, `<ctrl>q`, sends matches to the quickfix list
  * See [plugin.fzf.vim](./home-manager/modules/neovim/plugins/fzf.vim) for more

## Code / LSP
  * `gD` go to declaration
  * `gd` go to definition
  * `gi` find all implementations
  * `go` go to type definiton
  * `K` Displays hover information about a symbol
  * `<space>rn` rename symbol
  * `<space>ca` code action on code or block (ex: extract function)
  * `gr` list all references of a symbol (to quickfix)
  * `<space>f` format code
  * `<leader>cc` comment
  * `<leader>cu` uncomment
  * `<ctrl>o` go back to previous cursor
  * `<ctrl>i` go forward to next cursor

## Git (g)
  * `<leader>gs` show status pane
  * `:Git` or `:G` or `<leader>fgs` git status
  * `<leader>fgb` git branches
  * `:Gdiff` to see diff
  * `:Gwrite` stages current file
  * `:Gcommit` to commit
  * `:Glog` to show log
  * `:Gblame` to show blame

  * `<leader>gu` undo hunk
  * `<leader>gs` stage hunk
  * `]h` next hunk
  * `[h` prev hunk
  * `<leader>ggm` switch gutter base to main branch
  * `<leader>ggd` switch gutter base to default

  * `<leader>gdo` diff view open
  * `<leader>gdb` diff view open, diffing against main branch
  * `<leader>gdq` diff view close


## Diagnostics (x)
  * `<leader>xs` or `<leader>xf` Open diagnostic float
  * `<leader>xn` or `]x` Go to next diagnostic
  * `<leader>xp` or `[x` Go to previous diagnostic
  * `<leader>xo` Open diagnostic panel (Trouble)
  * `<leader>xq` Close diagnostic panel (Trouble)


## Nvim tree
  * `<ctrl>e` to toggle filetree
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

## Quickfix (k)
* `<leader>ko` to open quickfix
* `<leader>kq` to close quickfix
* `<leader>kn` or `]k` to go to next quickfix
* `<leader>kp` or `[k` to go to prev quickfix
* `<leader>kf` to find in quickfix

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
    * `?` to see all keymaps

## Misc
  * `<leader>r` to execute current buffer in a shell (normal mode)
  * `<leader>r` to execute current visual selection in a shell (visual mode)
  * `<leader>ym` to toggle mouse support (useful to allow select + copy)
  * `<leader>y` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
  * `<leader>yp` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util

## Commands
  * `Rename <file name>` to rename current file
  * `New <file name>` to create a file in current buffer dir
  * `Delete` to delete current file

