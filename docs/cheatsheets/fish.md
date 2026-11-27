# Fish sheet cheat

* Foreign env is used to source `~/.profile`. Any local variables can be set there.
* Paths: fish uses `fish_user_paths` to define paths and can be persisted when using "universal variables" (set with `-U`).
  * To add a path: `fish_add_path /some/new/path` or `set -Ua fish_user_paths /some/new/path`
  * To list current paths: `echo $fish_user_paths | tr " " "\n" | nl`
  * To remove a path: `set --erase fish_user_paths[NUMBER AS LISTED STARTING AT 1]`

* Shortcuts
  * See <https://fishshell.com/docs/current/interactive.html#shared-bindings> for all shortcuts
  * With no input `<alt><left>` or `<alt><right>` to jump to previous directory in history
  * With input `<alt><left>` or `<alt><right>` to between words
  * With input `<ctl>w` to delete previous word
  * With input `<alt>e` or `<alt>v` to open input in editor
  * `<ctl>r`: search history
  * `<ctl><alt>t`: search files
  * `<ctl><alt>f`: search directory
  * `<alt>c`: search cd directory
  * `<ctl><alt>p`: search processes
  * `<ctl><alt>l`: search git log
  * `<ctl><alt>s`: search git status
  * `<ctl>g`: select a Jujutsu revision
  * `<ctrl>v`: search env variables
  * `<ctl><alt>n`: search nix packages
  * `<ctl><alt>g`: rigrep search

* Monitor a command in Herdr (`monitor`, abbreviation `m`)
  * `m <cmd> [args...]`: run a command; Herdr shows it working, then done (exit 0) or error (other exits)
  * Already running? Press `<ctl>z`, then `m fg` to resume the same job under monitoring
    * With several stopped jobs: `m fg %N`, with `N` from `jobs`
  * Ctrl-C or another `<ctl>z` ends monitoring as `idle`, not done or error
  * Only reports inside a Herdr pane (`HC_TERMINAL_ID` set); elsewhere it just runs or resumes the command
  * Full-screen apps that handle `<ctl>z` themselves (vim, less, ...) may not suspend
