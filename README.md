
# Nixified dotfiles

## TODO

- [ ] Switch to the new RTX plugin?? https://github.com/jdxcode/rtx/pull/239/files
- [ ] Switch env variables to <https://discourse.nixos.org/t/home-manager-doesnt-seem-to-recognize-sessionvariables/8488> ?
- [ ] Copy rest of cheat sheets
- [ ] On the fly binary definition: <https://github.com/Mic92/dotfiles/blob/main/home-manager/modules/rust.nix>

## Initial setup

1. Make sure that fish is installed and is the default shell. Otherwise it won't properly setup for fish but only for currently running shell.

2. Download nix installer & run it with multi-user mode enabled: `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

3. [Install nix](https://nixos.org/download.html)

4. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf`

5. On Linux, configure nix by adding to `/etc/nix/nix.conf`.
   No need to do it on Darwin since we already do it nix-darwin (see [configuration.nix](./darwin/mbpapp/configuration.nix))

   ```conf
      keep-outputs = true
      keep-derivations = true
      auto-optimise-store = true

      # assuming the builder has a faster internet connection
      builders-use-substitutes = true

      experimental-features = nix-command flakes
   ```

6. On MacOS, apply darwin config: `./x build-darwin` and `./x activate-darwin`
   1. Activate shell by adding `/usr/local/bin/fish` to `/etc/shells` and running `chsh -s /usr/local/bin/fish`
   2. Select a patched nerdfonts font in iTerm2 in order to have icons in neovim.

7. Build `./x build` and activate `./x activate`
   1. On Linux, you may have to change shell to fish: `usermod -s /home/$USER/.nix-profile/bin/fish $USER`

## Troubleshooting

1. It seems that when switching to newer fish, the paths weren't properly set.
   They should look like:
     - /nix/var/nix/profiles/default/bin
     - /home/appaquet/.nix-profile/bin

## Cheat sheets

### Fish

- Foreign env is used to source `~/.profile`. Any local variables can be set there.
- Paths: fish uses `fish_user_paths` to define paths and can be persisted when using "universal variables" (set with `-U`).
  - To add a path: `fish_add_path /some/new/path` or `set -Ua fish_user_paths /some/new/path`
  - To list current paths: `echo $fish_user_paths | tr " " "\n" | nl`
  - To remove a path: `set --erase fish_user_paths[NUMBER AS LISTED STARTING AT 1]`

- Shortcuts
  - See <https://fishshell.com/docs/current/interactive.html#shared-bindings> for all shortcuts
  - With no input `<alt><left>` or `<alt><right>` to jump to previous directory in history
  - With input `<alt><left>` or `<alt><right>` to between words
  - With input `<ctl>w` to delete previous word
  - With input `<alt>e` or `<alt>v` to open input in editor (doesn't work on MacOS)

### Neovim

- Shortcuts
  - `<leader>` is configured to `\` (backslash)
  - `<leader> 1 through 9` to switch between opened buffers
  - `<leader>]` to switch to next buffer
  - `<leader>[` to switch to previous buffer
  - `<leader>w` to save current buffer
  - `<leader>x` to save and then execute current buffer (as long as it's chmod +x)
  - `<leader>z` to execute current visual selection in a shell
  - `<leader>r` to save current buffer and then execute `rsync.sh` in working dir
  - `<leader>q` to close the current buffer (equivalent to `:q`)
  - `<leader>w` to close the current buffer by trying not to messup the layout
  - `<leader><tab>` to switch between tab and spaces
  - `<ctrl>e` or `<leader>e` to toggle Nerdtree (files)
  - `<leader>d` if YouCompleteMe is available, go to definition
  - `<ctrl>p` fuzzy finding file
  - `<ctrl>a` fuzzy find the current word in files using ack
  - `<leader>m` to toggle mouse support (useful to allow select + copy)
  - `<leader>y` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
  - `<leader>p` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util

- Commands
  - `E <file>`: open a new buffer for a new file in current buffer's directory
  - `Delete`: delete current buffer's file

### tmux

- Shortcuts
  - See <https://github.com/gpakosz/.tmux> for all shortcuts
  - `<ctrl>b e` to toggle synchronized panes
  - `<ctrl>b m` to toggle mouse support (useful to allow select + copy)
  - `<ctrl>b <ctrl>l` to navigate to next window
  - `<ctrl>b <ctrl>h` to navigate to prev window
  - `<ctrl>b Tab` to navigate to last window
  - `<ctrl>b <tab>` to navigate to last window
  - `<ctrl>b <alt><arrows>` to resize pane
  - `<ctrl>b r` to reload config
  - `<ctrl>b <enter>` to get into copy mode
    - `v` for selection
    - `ctrl-v` to switch between between block and line selection
    - `y` to yank
    - `H` and `L` start line / end line
  - `<ctrl>b q` to show pane ids, then `:swap-pane -s X -t Y` to swap

- Plugins (via integrated .tmux.conf's tpm)
  - [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
    - `<ctrl>b <ctrl>s` to save current layout
    - `<ctrl>b <ctrl>r` to ressurect last saved layout
