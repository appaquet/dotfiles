# Tmux sheet cheat

* See <https://github.com/gpakosz/.tmux> for all shortcuts
* My prefixes are `ctrl-a` and `ctrl-space`
* `<prefix> <ctrl>l / h` to navigate to next / prev window
* `<prefix> L / H / J / K` to resize pane
* `<prefix> l / h / j / k` to navigate between panes
* `<prefix> ;` to switch to last pane
* `<prefix> <ctrL>y / <ctrl>u` to swap window left / right
* `<prefix> <tab>` to navigate to last window
* `<prefix> S` to toggle synchronized panes
* `<prefix> m` to toggle mouse support (useful to allow select + copy)
* `<prefix> r` to reload config
* `<prefix> <space>` used to toggle terminal bellow in an editor, moving cursor
* `<prefix> <enter>` to get into copy mode
  * `v` for selection
  * `ctrl-v` to switch between between block and line selection
  * `y` to yank
  * `H` and `L` start line / end line
* `<prefix> q` to show pane ids, then `:swap-pane -s X -t Y` to swap
* History search
  * Enable copy mode: `<prefix> [`
  * Use `?` or `/` and then navigate matches with `n` or `N`

* Plugins (via integrated .tmux.conf's tpm)
* [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
  * `<prefix> <ctrl>s` to save current layout
  * `<prefix> <ctrl>r` to ressurect last saved layout
