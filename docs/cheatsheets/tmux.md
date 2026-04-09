# Tmux Cheat Sheet

Prefix is `C-a`. Mouse is enabled by default.

## Panes

* `<prefix> "` Split horizontally (inherits cwd)
* `<prefix> %` Split vertically (inherits cwd)
* `<prefix> h/j/k/l` Navigate panes (vim-style)
* `<prefix> H/J/K/L` Resize pane (repeatable)
* `<prefix> =` Equalize pane layout
* `<prefix> x` Kill pane (no confirmation)
* `<prefix> q` Show pane numbers (then `:swap-pane -s X -t Y` to swap)
* `<prefix> S` Toggle synchronized panes
* `<prefix> C-k` Clear screen across all synced panes

## Windows

* `<prefix> c` New window (inherits cwd)
* `<prefix> C-h` Previous window (repeatable)
* `<prefix> C-l` Next window (repeatable)
* `<prefix> C-y` Swap window left (repeatable)
* `<prefix> C-u` Swap window right (repeatable)
* `<prefix> &` Kill window (no confirmation)
* `<prefix> w` Fuzzy-find and switch window (fzf, across all sessions)

## Sessions

* `<prefix> C-c` Create new named session
* `<prefix> X` Kill current session
* `<prefix> W` Open tmux-fzf launcher (sessions, windows, panes, commands)

## Copy Mode (vi-style)

* `<prefix> [` Enter copy mode
* `v` Start selection
* `C-v` Toggle block / line selection
* `y` Yank selection
* `H` / `L` Start / end of line
* `?` / `/` Search backward / forward
* `n` / `N` Next / previous match

## Misc

* `<prefix> M` Toggle mouse on/off (disable for terminal text selection + copy)
* `<prefix> r` Reload config

## Plugins

### tmux-resurrect

* `<prefix> C-s` Save current session layout
* `<prefix> C-r` Restore last saved layout
