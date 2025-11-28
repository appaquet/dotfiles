# Neovim sheet cheat

This is a collection of keymaps and commands for my Neovim setup. It doesn't contain only personal
keymaps, but also default/built-ins that I tend to forget.

## General keymap

* `<leader>` is space
* `<leader>qq` to close current window/split
* `<leader>qa` to quit neovim
* `<leader>qs` to clear auto-session and quit neovim
* `<leader>o` to open messages in floating window
* `<leader>qn` to dismiss all notifications

## Buffers (b)

* `]b` to switch to next buffer
* `[b` to switch to previous buffer
* `<leader>bc` to open a new empty buffer
* `<leader>bu` to undo changes (reload from disk)
* `<leader>bq` or `<leader>bqq` to close the current buffer by trying not to mess up the layout
* `<leader>bqo` to close all buffers except the current one
* `<leader>bqa` to close all buffers
* `<leader>bm` to create buffer from messages
* `<leader>w`, `<leader>ww` to save current buffer
* `<leader>wa` to save all buffers

## Tabs (n)

* `<leader>nc` to open a new tab
* `]n` to switch to next tab
* `[n` to switch to previous tab
* `<leader>n1 through 6` to switch to tab 1 through 6
* `<leader>nq` to close current tab
* `<leader>n<tab>` to switch to last tab

## Windows

* `ctrl-w w` to swap left and right window buffers
* `ctrl-w r` or `ctrl-w R` to rotate panes
* `ctrl-w c` or `ctrl-w o` close current split OR others
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
* `<ctrl-n>` or `<leader>fn` fuzzy find through tabs
* `<ctrl-h>` or `<leader>fo` fuzzy find through old files
* `<leader>flS` fuzzy find through workspace symbols
* `<leader>flr` fuzzy find through LSP references
* `<leader>flc` fuzzy find through LSP incoming calls
* `<leader>flC` fuzzy find through LSP outgoing calls
* `<leader>fld` fuzzy find through LSP definitions
* `<leader>flD` fuzzy find through LSP declarations
* `<leader>flt` fuzzy find through LSP type definitions
* `<leader>fli` fuzzy find through LSP implementations
* `<leader>flm` fuzzy find through LSP document diagnostics
* `<leader>flM` fuzzy find through LSP workspace diagnostics
* `<leader>fdb` fuzzy find through DAP breakpoints
* `<leader>fw` fuzzy find word under cursor in file
* `<leader>fW` fuzzy find word under cursor in workspace
* `<leader>fk` fuzzy find through keymaps
* `<leader>fc` fuzzy find through neovim commands
* `<leader>fr` to resume last search
* `<leader>fh` fuzzy find through help tags
* `<leader>fm` fuzzy find through marks
* `<leader>fR` fuzzy find through registers
* `<leader>fx` or `<leader>fxl` fuzzy find through quickfix list
* `<leader>fxs` fuzzy find through quickfix stack

### Git integration

* `<leader>fgs` fuzzy find through git status
* `<leader>fgb` fuzzy find through git branches
* `<leader>fgS` fuzzy find through git stash
* `<leader>fgf` fuzzy find through git files
* `<leader>fgB` fuzzy find through git blame
* `<leader>fgt` fuzzy find through git tags

### Inside fzf window

* `<ctrl-d>` or `<ctrl-u>` to page through results
* `<shift-up>` or `<shift-down>` to page through preview
* `<ctrl-i>` to select matches
* `<ctrl-k>` to select all + send matches to quickfix list
* `<ctrl-v>` to open selection in vertical split
* `<ctrl-s>` to open selection in horizontal split
* `<ctrl-t>` to open selection in tabs
* `<alt-i>` to toggle ignored files
* `<alt-h>` to toggle hidden files
* `<alt-f>` to toggle follow symlinks

### Insert-mode completions

* `<ctrl-x><ctrl-f>` to fuzzy complete files/paths
* See [fzf.lua](/home-manager/modules/neovim/conf/fzf.lua) for all keymaps

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
  * `<leader>fS` fuzzy find content in selected directory 
  * `<leader>ff` fuzzy find files in selected directory 
  * `<leader>gdf` show git file/directory history
  * `<leader>cs` add file to Claude context

## LSP / lang

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
* `<ctrl-l>r` LSP: Rename (insert|visual mode)
* `<leader>lca` or `gra` LSP: Code action
* `<ctrl-l>ca` LSP: Code action (insert|visual mode)
* `<leader>lci` LSP: Fix imports (Go)
* `<leader>lR` LSP: Restart LSP
* `<leader>lwa` LSP: Add workspace folder
* `<leader>lwr` LSP: Remove workspace folder
* `<leader>lwl` LSP: List workspace folders
* `<leader>lf` Format current buffer with conform
* `gfd` LSP: Go to definition in floating window
* `gft` LSP: Go to type definition in floating window
* `gld` LSP: Go to definition in right split
* `glt` LSP: Go to type definition in right split

## Git (g)

* `<leader>gs` to show git status
* `:Git` or `:G` or `<leader>fgs` to show git status
* `<leader>fgb` to list git branches 
* `<leader>fgS` fuzzy find through git stash 
* `<leader>fgf` fuzzy find through git files 
* `<leader>fgB` fuzzy find through git blame 
* `<leader>fgt` fuzzy find through git tags 
* `:Gdiff` to see diff
* `:Gwrite` to stage the current file
* `:Gcommit` to commit changes
* `:Glog` to show git log
* `:Gblame` to show blame
* `<leader>gm` to change main branch
* `<leader>gy` to yank the current line GitHub URL
* `<leader>gu` to revert hunk
* `<leader>ga` to stage hunk
* `<leader>gb` to show blame pane
* `]g` to navigate to the next git hunk
* `[g` to navigate to the previous git hunk
* `<leader>ggm` to switch gutter base against main branch
* `<leader>ggp` to switch gutter base against previous branch
* `<leader>ggw` to switch gutter base to working set

### Diff view

* `<leader>gdw` to open diff view against working set
* `<leader>gdm` to open diff view against main branch
* `<leader>gdp` to open diff view against previous branch
* `<leader>gdc` to open diff view against given rev/commit
* `<leader>gdq` to close diff view
* `<leader>gdf` to open file history
* `<leader>gdb` to open buffer diff
* `<leader>Tdw` to toggle whitespace visibility

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
* `<leader>xr` Reset diagnostics
* `<leader>xl` Set location list
* `<leader>xo` Open diagnostic panel
* `<leader>xf` Focus diagnostic panel
* `<leader>xx` Toggle diagnostic panel
* `<leader>xq` Close diagnostic panel
* `]x` Go to next diagnostic (in file)
* `[x` Go to previous diagnostic (in file)
* `]X` Go to next diagnostic (global)
* `[X` Go to previous diagnostic (global)
* In diagnostic panel
  * `s` to toggle between severty levels

## Quickfix (k)

* `<leader>ko` to open quickfix
* `<leader>kq` to close quickfix
* `<leader>kk` to toggle quickfix
* `<leader>kc` to clear quickfix
* `<leader>kn` or `]k` to go to next quickfix
* `<leader>kp` or `[k` to go to prev quickfix
* From any fzf, `<ctrl>k`, sends matches to the quickfix list 
* Run replace in each quickfix match:
  * `:cdo %s/<pattern>/<replacement>/g` to replace in each quickfix match
  * `:cfdo %s/<pattern>/<replacement>/g` to replace in each quickfix match file

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
* `<leader>tq` to close output & side panel 

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
* In stacks
  * `o` to open the current stack frame
  * `t` to toggle hidden stack frames

## Inline AI code completion (insert mode)

* `<Alt-l>`: Accept word suggestion
* `<Alt-o>`: Accept line suggestion
* `<Alt-j>`: Next suggestion
* `<Alt-J>`: Show all suggestions in a panel
* `<Alt-k>`: Previous suggestion
* `<Alt-n>`: Accept NES suggestion and go to next edit
* `<ctrl-]>`: Dismiss suggestion
* `<Tab>`: Accept suggestion if visible, otherwise expand/jump snippet or insert tab
* `<Shift-Tab>`: Force insert a tab instead of expanding a snippet

## Toggle Options (T)

* `<leader>Tm` to toggle mouse support (useful to allow select + copy)
* `<leader>Tn` to toggle line numbers
* `<leader>Tw` to toggle line wrap
* `<leader>Ts` to toggle spell checking
* `<leader>Ti` to toggle LSP inlay hints
* `<leader>Tp` to toggle Copilot
* `<leader>Tf` to toggle auto-formatting
* `<leader>Tl` to toggle auto linting
* `<leader>Tt` to toggle theme between light and dark
* `<leader>Tdw` to toggle whitespace visibility

## AI Tools

* `<leader>au` to open MCPHub
* `<leader>aa` to show CodeCompanion actions
* `<leader>ae` inline edit with prompt in visual mode

### Claude Integration

* `<leader>cc` to toggle Claude
* `<leader>cf` to focus Claude
* `<leader>cr` to resume Claude
* `<leader>cC` to continue Claude
* `<leader>cb` to add current buffer to Claude
* `<leader>cs` to send selection to Claude (visual) / add file to Claude (in tree)
* `<leader>ca` to accept diff
* `<leader>cd` to deny diff

## Visual AI actions

This uses code companion. Use `ga` and `gr` to accept/reject AI suggestions in visual mode.

* `gs` use Code Companion to correct spelling and improve clarity of the current selection
* `gC` generate comments or documentation for the current selection

## Object selection (in visual mode)

* `aX`: Select around object X
* `iX`: Select inside object X
  *(X = (p)arameter, (f)unction, (c)lass, (b)lock)*

## Object movements

* `]X`: Next start of X
* `[X`: Previous start of X
* `]X`, `[X`: With capital letters → go to end
  *(X = (f)unction, (c)lass, con(d)itional)*
* `]d`: Next conditional
* `[d`: Previous conditional

## Object manipulations

* `<leader>Sp`: Swap with next parameter
* `<leader>Sf`: Swap with next function
* `<leader>SP`: Swap with previous parameter
* `<leader>SF`: Swap with previous function

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

## Execute/Run Commands (r)

* `<leader>rf` to execute current file in a shell
* `<leader>rl` to execute current visual selection in a shell (visual mode)
* `<leader>rb` to execute code block in a shell

## Clipboard Operations (y)

* `<leader>yy` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
* `<leader>yp` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util
* `<leader>yc` to yank the current line and comment the previous one
* `<leader>yf` to yank current file's absolute path

## Marks (m)

* `<leader>mk` to delete all marks

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

## Linting

* `<leader>lt` to run linting on demand
* `<leader>Tl` to toggle auto linting

## Profiling (P)

* `<leader>Pt` to toggle profiler
* `<leader>Ph` to toggle profiler highlights

## Misc

* `zz` to center cursor in the middle of the screen
* `<ctrl-/>` to clear search highlights

## Spelling

* `<leader>Ts` to toggle spell checking
* `]s` or `[s` to go to next/prev spelling error
* `z=` to see spelling suggestions for word under cursor
* `zg` to add word under cursor to spelling dictionary
  (`1zg`, `2zg`, if multiple dicts. Check `echo &spellfile` for order)
* `zw` to remove word under cursor from spelling dictionary
* `gs` use code companion to correct spelling & clarity of current selection
  (use `ga` or `gr` to accept/reject)

## Command-line shortcuts

* `w!!` to save file with sudo
* Various typo protection: `Wq`, `WQ`, `wQ` all mapped to `wqa` (write all and quit)
