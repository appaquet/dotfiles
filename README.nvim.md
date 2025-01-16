# Neovim README

## General keymap
  * `<leader>` is `\` (backslash)
  * `<leader>qq` to close current pane
  * `<leader>qa` to quit vim
  * `<leader>m` to toggle mouse support (useful to allow select + copy)

## Buffers
  * `<leader> 1 through 9` to switch between opened buffers
  * `<leader>]` to switch to next buffer
  * `<leader>[` to switch to previous buffer
  * `<leader>s` to save current buffer
  * `<leader>w` to close the current buffer by trying not to mess up the layout
  * `<leader>wo` to close all buffers except the current one
  * `<leader>wa` to close all buffers

## Fzf
  * `<ctrl>p` or `<leader>ff` fuzzy finding file names
  * `<ctrl-l>` or `<leader>fs` fuzzy find in current file
  * `<ctrl-g>` or `<leader>fS` fuzzy find in workspace (ripgrep)
  * `<ctrl-b>` or `<leader>fb` fuzzy find through buffers
  * `<ctrl-\>` fuzzy find through neovim commands
  * `<leader>fk` fuzzy find through keymaps
  * When open, `<ctrl>q`, sends matches to the quickfix list
  * See [plugin.fzf.vim](./home-manager/modules/neovim/plugins/fzf.vim) for more

## Editing & navigation
  * `<leader>y` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
  * `<leader>p` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util
  * `<ctrl>o` go back to previous cursor
  * `<ctrl>i` go forward to next cursor
  * `<leader>cc` comment
  * `<leader>cu` uncomment

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

## Diagnostics
  * `<leader>ds` or `<leader>df` Open diagnostic float
  * `<leader>dn` or `]d` Go to next diagnostic
  * `<leader>dp` or `[d` Go to previous diagnostic
  * `<leader>do` Open diagnostic panel (Trouble)
  * `<leader>dq` Close diagnostic panel (Trouble)


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

## Git
  * `:Git` or `:G` or `<leader>fgs` git status
  * `<leader>fgb` git branches
  * `:Gdiff` to see diff
  * `:Gwrite` stages current file
  * `:Gcommit` to commit
  * `:Glog` to show log
  * `:Gblame` to show blame

## Quickfix
* `<leader>xo` to open quickfix
* `<leader>xq` to close quickfix
* `<leader>xn` or `]x` to go to next quickfix
* `<leader>xp` or `[x` to go to prev quickfix
* `<leader>xf` to find in quickfix

## Testing
  * `<leader>tc` to run nearest / under cursor
  * `<leader>tdc` to debug nearest
  * `<leader>tf` to run file
  * `<leader>tdf` to debug file
  * `<leader>tl` to run last
  * `<leader>tdl` to debug last
  * `<leader>ts` to stop test
  * `<leader>to` to open output panel
  * `<leader>tk` to clear output panel
  * `<leader>tq` to close output panel

## Misc
  * `<leader>r` to execute current buffer in a shell (normal mode)
  * `<leader>r` to execute current visual selection in a shell (visual mode)

## Commands
  * `Rename <file name>` to rename current file
  * `Edit <file name>` to create a file in current buffer dir
  * `Delete` to delete current file

