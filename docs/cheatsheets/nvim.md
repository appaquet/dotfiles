# Neovim Cheat Sheet

This is a collection of keymaps and commands for my Neovim setup. It doesn't contain only personal
keymaps, but also default/built-ins that I tend to forget.

## General Keymap

* `<leader>` is space
* `<leader>qq` Close current window/split
* `<leader>qa` Quit neovim
* `<leader>qs` Clear session and quit neovim
* `<leader>qn` Dismiss all notifications
* `<leader>o` Open messages in floating window
* `<A-j>` Move down 5 lines
* `<A-k>` Move up 5 lines
* `<C-/>` Clear search highlights

## Buffers (b)

* `<leader>bc` Open new empty buffer
* `<leader>bu` Undo changes (reload from disk)
* `<leader>bq` or `<leader>bqq` Close current buffer
* `<leader>bqo` Close all buffers except current
* `<leader>bqa` Close all buffers
* `<leader>bm` Create buffer from messages
* `<leader>w` or `<leader>ww` Save current buffer
* `<leader>wa` Save all buffers

## Tabs (n)

* `<leader>nc` Open new tab
* `]n` Switch to next tab
* `[n` Switch to previous tab
* `<leader>n1` through `<leader>n6` Switch to tab 1-6
* `<leader>nq` Close current tab
* `<leader>n<Tab>` Switch to last tab

## Windows

* `<C-w>w` Swap left and right window buffers
* `<C-w>r` or `<C-w>R` Rotate panes
* `<C-w>c` or `<C-w>o` Close current split OR others
* `<C-w>z` Toggle zen mode
* `<C-w>pl` Pop current buffer to right window and navigate back
* `<C-w>pf` Pop current buffer to a floating window and navigate back
* `<C-w>]` Increase window width
* `<C-w>[` Decrease window width
* `<C-w>m` Set window width to 80% of screen

## Fzf (f)

* `<C-p>` or `<leader>ff` Fuzzy find file names (can also be used in tree)
* `<C-l>` or `<leader>fs` Fuzzy find content in current file
* `<C-g>` or `<leader>fS` Fuzzy find content in workspace (can also be used in tree)
* `<C-b>` or `<leader>fb` Fuzzy find through buffers
* `<C-s>` or `<leader>fls` Fuzzy find through document symbols
* `<C-n>` or `<leader>fn` Fuzzy find through tabs
* `<C-h>` or `<leader>fo` Fuzzy find through old files
* `<leader>flS` Fuzzy find through workspace symbols
* `<leader>flr` Fuzzy find through LSP references
* `<leader>flc` Fuzzy find through LSP incoming calls
* `<leader>flC` Fuzzy find through LSP outgoing calls
* `<leader>fld` Fuzzy find through LSP definitions
* `<leader>flD` Fuzzy find through LSP declarations
* `<leader>flt` Fuzzy find through LSP type definitions
* `<leader>fli` Fuzzy find through LSP implementations
* `<leader>flm` Fuzzy find through LSP document diagnostics
* `<leader>flM` Fuzzy find through LSP workspace diagnostics
* `<leader>fdb` Fuzzy find through DAP breakpoints
* `<leader>fw` Fuzzy find word under cursor in file
* `<leader>fW` Fuzzy find word under cursor in workspace
* `<leader>fk` Fuzzy find through keymaps
* `<leader>fc` Fuzzy find through neovim commands
* `<leader>fr` Resume last search
* `<leader>fh` Fuzzy find through help tags
* `<leader>fm` Fuzzy find through marks
* `<leader>fR` Fuzzy find through registers
* `<leader>fx` or `<leader>fxl` Fuzzy find through quickfix list
* `<leader>fxs` Fuzzy find through quickfix stack

### Git Integration

* `<leader>fgs` Fuzzy find through git status
* `<leader>fgb` Fuzzy find through git branches
* `<leader>fgS` Fuzzy find through git stash
* `<leader>fgf` Fuzzy find through git files
* `<leader>fgB` Fuzzy find through git blame
* `<leader>fgt` Fuzzy find through git tags

### Inside FZF Window

* `<C-d>` or `<C-u>` Page through results
* `<S-Up>` or `<S-Down>` Page through preview
* `<C-i>` Select matches
* `<C-k>` Select all + send matches to quickfix list
* `<C-v>` Open selection in vertical split
* `<C-s>` or `<C-x>` Open selection in horizontal split
* `<C-t>` Open selection in tabs
* `<A-i>` Toggle ignored files
* `<A-h>` Toggle hidden files
* `<A-f>` Toggle follow symlinks

### Inside FZF Buffers Window

* `<C-d>` Force delete buffer
* `<C-x>` Delete buffer

### Insert-Mode Completions

* `<C-x><C-f>` Fuzzy complete files/paths

## Nvim Tree

* `<leader>e` Toggle filetree
* In tree
  * `g?` Show help
  * `<C-]>` CD into directory
  * `-` Go up one directory
  * `<C-v>` Open in vertical split
  * `<C-x>` Open in horizontal split
  * `I` Toggle hidden files
  * `r` Rename file
  * `d` Delete file
  * `a` Add file or directory (if ends with `/`)
  * `c`, `x`, `v` Copy, cut, paste files
  * `f` Find file, `F` to clear
  * `q` Close tree
  * `E` Expand all, `W` Collapse all
  * `/` Fuzzy find file in tree
  * `<leader>fS` Fuzzy find content in selected directory
  * `<leader>ff` Fuzzy find files in selected directory
  * `<leader>gdf` Show git file/directory history
  * `<leader>cs` Add file to Claude context

## LSP (l)

* `<leader>lgd` or `gd` Go to definition
* `<leader>lgt` or `gt` Go to type definition
* `<leader>lli` List all implementations
* `<leader>llr` List references
* `<leader>lii` Display hover information about symbol
* `<leader>lis` Show signature help
* `<leader>Ti` Toggle inlay hints
* `<leader>lr` Rename
* `<C-l>r` Rename (insert/visual mode)
* `<leader>lca` Code action
* `<C-l>ca` Code action (insert/visual mode)
* `<leader>lci` Fix imports
* `<leader>lR` Restart LSP
* `<leader>lwa` Add workspace folder
* `<leader>lwr` Remove workspace folder
* `<leader>lwl` List workspace folders
* `<leader>lf` Format current buffer
* `<leader>lt` Run linting on demand
* `<leader>lT` Fix linting issues
* `gfd` Go to definition (floating window)
* `gft` Go to type definition (floating window)
* `gld` Go to definition (right split)
* `glt` Go to type definition (right split)

## Git (g)

* `<leader>gs` Show git status
* `<leader>gm` Change main branch
* `<leader>gy` Yank current line GitHub URL
* `<leader>gu` Revert hunk
* `<leader>ga` Stage hunk
* `<leader>gb` Show blame pane
* `<leader>gdb` Open buffer diff
* `]g` Navigate to next git hunk
* `[g` Navigate to previous git hunk
* `<leader>ggm` Switch gutter base to main branch
* `<leader>ggp` Switch gutter base to previous branch
* `<leader>ggw` Switch gutter base to working set

### Git Commands

* `:Git` or `:G` Show git status
* `:Gdiff` Show diff
* `:Gwrite` Stage current file
* `:Gcommit` Commit changes
* `:Glog` Show git log
* `:Gblame` Show blame

### Diff View

* `<leader>gdw` Open diff view against working set
* `<leader>gdm` Open diff view against main branch
* `<leader>gdp` Open diff view against previous branch
* `<leader>gdc` Open diff view against given rev/commit
* `<leader>gdq` Close diff view
* `<leader>gdf` Open file history
* `<leader>Tdw` Toggle whitespace visibility

### PR review

* `<leader>gpo` Open PR review mode
* `<leader>gpq` Close PR review mode
* `<leader>gpl` List PRs
* `<leader>gpc` Review comments
* `<leader>gps` Submit review
* Files:
  * `]q` and `[q` Navigate between files
  * `]Q` and `[Q` Navigate to first/last files
  * `<leader>space` Toggle file as reviewed
  * `gf` Open file
* Comments:
  * `<leader>ca` Add comment
  * `<leader>cd` Delete comment
  * `<leader>sa` Add line suggestion
  * `<leader>r` Add reaction
  * `]c` and `[c` Navigate between comments
* Review actions:
  * `<C-m>` Submit with comment
  * `<C-a>` Approve
  * `<C-r>` Request changes

## Diagnostics (x)

* `<leader>xs` Open diagnostic float
* `<leader>xf` Open or focus diagnostic panel
* `<leader>xr` Close diagnostics
* `<leader>xl` Set location list
* `<leader>xo` Open diagnostic panel
* `<leader>xx` Toggle diagnostic panel
* `<leader>xq` Close diagnostic panel
* `]x` Go to next diagnostic (in file)
* `[x` Go to previous diagnostic (in file)
* `]X` Go to next diagnostic (global, opens panel)
* `[X` Go to previous diagnostic (global, opens panel)
* In diagnostic panel
  * `s` to toggle between severity levels

## Quickfix (k)

* `<leader>ko` Open quickfix
* `<leader>kq` Close quickfix
* `<leader>kk` Toggle quickfix
* `<leader>kc` Clear quickfix
* `<leader>kn` or `]k` Go to next item
* `<leader>kp` or `[k` Go to previous item
* From any fzf, `<C-k>` sends all matches to quickfix list

### Replace in quickfix matches

* `:cdo %s/<pattern>/<replacement>/g` Replace in each match
* `:cfdo %s/<pattern>/<replacement>/g` Replace in each file

## Testing (t)

* `<leader>tc` Run nearest test / under cursor
* `<leader>tdc` Debug nearest test
* `<leader>tf` Run file tests
* `<leader>tdf` Debug file tests
* `<leader>tp` Run package/directory tests
* `<leader>tdp` Debug package/directory tests
* `<leader>tl` Run last test
* `<leader>tdl` Debug last test
* `<leader>tu` Stop test
* `<leader>to` Show output pane
* `<leader>tq` Close output & side panel
* `<leader>ts` Toggle side/summary panel with keymaps:
  * `r` Run a test
  * `u` Stop a test
  * `i` Open test source
  * `?` Show help

## Debugging (d)

* `<leader>db` Toggle breakpoint
* `<leader>dc` Start/continue debugging
* `<leader>do` Step over
* `<leader>dI` Step into
* `<leader>dO` Step out
* `<leader>dj` Move down in stack trace
* `<leader>dk` Move up in stack trace
* `<leader>dp` Pause execution
* `<leader>dt` Terminate debugging session
* `<leader>dr` Restart debugging session
* `<leader>de` Toggle REPL
* `<leader>dl` Run last
* `<leader>dC` Run to cursor
* `<leader>du` Open DAP UI
* `<leader>dq` Terminate & quit DAP UI
* In stack frames:
  * `o` Open current stack frame
  * `t` Toggle hidden stack frames

## Inline AI Code Completion (Insert Mode)

* `<M-l>` Accept word suggestion
* `<M-o>` Accept line suggestion
* `<M-j>` Next suggestion
* `<M-k>` Previous suggestion
* `<M-n>` Accept suggestion and go to next edit
* `<C-]>` Dismiss suggestion
* `<M-J>` Show Copilot panel
* `<Tab>` Accept suggestion if visible, apply next edit suggestion, expand snippet, or insert tab
* `<S-Tab>` Insert tab (skip snippet expansion and suggestions)

## Toggle Options (T)

* `<leader>Tm` Toggle mouse support
* `<leader>Tn` Toggle line numbers
* `<leader>Tw` Toggle line wrap
* `<leader>Ts` Toggle spell checking
* `<leader>Ti` Toggle LSP inlay hints
* `<leader>Tp` Toggle Copilot
* `<leader>Tf` Toggle auto-formatting
* `<leader>Tl` Toggle auto linting
* `<leader>Tt` Toggle theme (light/dark)
* `<leader>Tdw` Toggle whitespace visibility

## AI Tools (a)

* `<leader>aa` Show CodeCompanion actions
* `<leader>ae` Inline edit with prompt (visual mode)

### Claude Integration (c)

* `<leader>cc` Toggle Claude
* `<leader>cf` Focus Claude
* `<leader>cr` Resume Claude
* `<leader>cC` Continue Claude
* `<leader>cb` Add current buffer to Claude
* `<leader>cs` Send selection to Claude (visual) / add file (tree)
* `<leader>ca` Accept diff
* `<leader>cd` Deny diff

### Visual AI actions

* `gs` Fix spelling and improve clarity (visual mode)
* `gC` Add or improve documentation/comments (visual mode)

## PKMS (m)

Personal Knowledge Management System keymaps. Works from any directory - opens floating window when
not in PKMS, operates in-place when already in a PKMS buffer.

* `<leader>md` Toggle daily note (float if not in PKMS, in-place if in PKMS)
* `<leader>mjd` Open today's note
* `<leader>mjy` Open yesterday's note
* `<leader>mjt` Open tomorrow's note
* `<leader>mf` Find files in PKMS vault
* `<leader>ms` Search content in PKMS vault
* `<leader>mS` Search workspace symbols via LSP
* `<leader>mt` Insert template

## Projects (p)

* `<leader>po` Open main project doc (00-*.md)
* `<leader>pf` Find files in proj/
* `<leader>fp` Find files in proj/ (alias)
* `<leader>ps` Search content in proj/

## Object selection (in visual mode)

* `aX`: Select around object X
* `iX`: Select inside object X
  *(X = (p)arameter, (f)unction, (c)lass, (b)lock)*

## Object movements

* `]X`: Next start of X
* `[X`: Previous start of X
* `]X`, `[X`: With capital letters → go to end
  *(X = (f)unction, (c)lass)*
* `]d`: Next conditional
* `[d`: Previous conditional

## Object manipulations

* `<leader>Sp`: Swap with next parameter
* `<leader>Sf`: Swap with next function
* `<leader>SP`: Swap with previous parameter
* `<leader>SF`: Swap with previous function

## Text/Code Manipulation

* `gw` Format text (in visual)
* `gc` Comment text (in visual)
* `gu` Lowercase text (in visual)
* `gU` Uppercase text (in visual)
* `g~` Toggle casing (in visual)
* `g;` and `g,` Navigate through last edits
* `<C-t>` Increase indent (insert mode)
* `<C-d>` Decrease indent (insert mode)
* `<C-n>` Start multicursor edit
  * A keymap helper will show up with the available keymaps
  * `n`, `N` Go to next/previous match
  * `q` Skip current match
  * `c` Change matches
  * `d` Delete matches
  * `a` Append after matches

## Templates (C-e)

### Todo (C-e t)

* `<C-e>ti` Insert new todo `- [ ] ` on next line
* `<C-e>td` Mark todo as done `[x]`
* `<C-e>tp` Mark todo as in progress `[~]`
* `<C-e>tu` Mark todo as undone `[ ]`

### Comment Tags (C-e c)

* `<C-e>cr` Insert `REVIEW: ` comment (filetype-aware)
* `<C-e>ct` Insert `TODO: ` comment (filetype-aware)
* `<C-e>cf` Insert `FIXME: ` comment (filetype-aware)
* `<C-e>cn` Insert `NOTE: ` comment (filetype-aware)

### Markdown

* `<C-e>b` Insert bullet `- `
* `<C-e>h1` Insert heading `# `
* `<C-e>h2` Insert heading `## `
* `<C-e>h3` Insert heading `### `
* `<C-e>h4` Insert heading `#### `

## Execute/Run Commands (r)

* `<leader>rf` Execute current file in a shell
* `<leader>rl` Execute current visual selection in a shell (visual mode)
* `<leader>rb` Execute code block in a shell

## Clipboard Operations (y)

* `<leader>yy` Yank selection to system clipboard (visual mode)
* `<leader>yp` Paste from system clipboard
* `<leader>yc` Copy line and comment previous one
* `<leader>yf` Copy current file's absolute path

## Marks (M)

* `<leader>Mk` Delete all marks

## Folding

* `zm` Fold more
* `zM` Fold all
* `zr` Unfold more
* `zR` Unfold all
* `za` Toggle fold under cursor
* `zz` Center cursor in screen

## Vim Marks

* `m[a-z0-9A-Z]` Set mark
* `'[a-z0-9A-Z]` List (which-key) and go to mark

## Recording & Registers

* `q[a-z0-9A-Z]` Start recording
* `q` Stop recording
* `@[a-z0-9A-Z]` Play macro (prefixed with number for repeats)
* `.` Replay last action/macro
* `"[a-z0-9A-Z]` Yank to register
* `"[a-z0-9A-Z]p` Paste from register (which-key list available)

## Profiling (P)

* `<leader>Pt` Toggle profiler
* `<leader>Ph` Toggle profiler highlights

## Spelling

* `<leader>Ts` Toggle spell checking
* `]s` or `[s` Navigate to next/previous spelling error
* `z=` Show spelling suggestions for word under cursor
* `zg` Add word to spelling dictionary
  (Use `1zg`, `2zg` for multiple dictionaries)
* `zw` Remove word from spelling dictionary
* `gs` Fix spelling/clarity (visual mode)

## Command-line Shortcuts

* `w!!` Save file with sudo
* `wq`, `Wq`, `WQ`, `wQa`, `WQa`, `wqaa`, `WQaa` Mapped to `wqa`
* `Qw`, `qw` Mapped to `wqq`
