
# Nixified dotfiles

## Initial setup

1. Download nix installer & run it with multi-user mode enabled: `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

2. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf`

3. On Linux, configure nix by adding to `/etc/nix/nix.conf`.
   No need to do it on Darwin since we already do it nix-darwin (see [configuration.nix](./darwin/mbpapp/configuration.nix))

   ```conf
      keep-outputs = true
      keep-derivations = true
      auto-optimise-store = true

      # assuming the builder has a faster internet connection
      builders-use-substitutes = true

      experimental-features = nix-command flakes
   ```

4. Build `./x home build` and activate `./x home switch`

5. Activate shell by adding `/home/appaquet/.nix-profile/bin/fish` to `/etc/shells`
   and running `chsh -s /home/appaquet/.nix-profile/bin/fish`

6. On MacOS, apply darwin config: `./x darwin build` and `./x darwin witch`
   2. Select a patched nerdfonts font in iTerm2 in order to have icons in neovim.

## Not covered

- Rust is not installed using Nix anymore as it breaks [cross](https://github.com/cross-rs/cross) since Rust
  binaries link with Nix libs. Cross does mount `/nix`, but it doesn't seem sufficient...

  See [this commit](https://github.com/appaquet/dotfiles/commit/4aebf75a47536c833140d463cbc1606d474e1f91).

  Install rustup manually instead, see https://rustup.rs/

- In order to enable mold, edit `~/.cargo/config` and add:
  ```toml
  [target.x86_64-unknown-linux-gnu]
  linker = "clang"
  rustflags = ["-C", "link-arg=-fuse-ld=/home/appaquet/.nix-profile/bin/mold"]
  ```


## Troubleshooting

1. It seems that when switching to newer fish, the paths weren't properly set.
   On top of that, it may be shadowed by a global fish path too. 
   Reset fish paths with:

   ```bash
   set -ge fish_user_paths
   set -Ua fish_user_paths /nix/var/nix/profiles/default/bin
   set -Ua fish_user_paths /home/appaquet/.nix-profile/bin
   ```

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
  - `<ctl><alt>n`: fzf nix packages
  - `<ctl><alt>g`: fzf ripgrep
  - `<ctl><alt>f`: fzf fd (find file)
  - `<ctl><alt>p`: fzf processes
  - `<ctl><alt>l`: fzf git log
  - `<ctl><alt>s`: fzf git status

### Neovim

#### Mapping
- General
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
  - `<ctrl>p` fuzzy finding file
  - `<ctrl>f` riggrep search
  - `<leader>m` to toggle mouse support (useful to allow select + copy)
  - `<leader>y` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
  - `<leader>p` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util

- LSP
  - `gD` goto declaration
  - `gd` goto definition
  - `gi` goto implementation
  - `K` hover info
  - `<space>rn` rename symbol

- Commands
  - `E <file>`: open a new buffer for a new file in current buffer's directory
  - `Delete`: delete current buffer's file

- Basics
  - `<ctrl>o` navigate back and `<ctrl>i` to navigate forward

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

## Resources

- <https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/trivial-builders.nix>
- <https://nix-community.github.io/home-manager/options.html>
- <https://daiderd.com/nix-darwin/manual/index.html#sec-options>

## TODO

- [ ] Manage brew through nix: <https://daiderd.com/nix-darwin/manual/index.html#opt-homebrew.enable>
- [ ] Find out how to declaratively install apt packages
