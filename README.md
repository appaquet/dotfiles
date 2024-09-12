
# Nixified dotfiles

## Initial setup (NixOS)

1. Setup NixOS using the installer.

1. Once installed, edit `/etc/nixos/configuration.nix` and rebuild:
   * Enable sshd
   * Enable flakes: `nix.settings.experimental-features = [ "flakes" ];`

1. SSH to the machine.

1. Clone this repo (need to setup keys, use a nix-shell with git and neovim).

1. Setup home-manager & enable.

1. Copy `/etc/nixos/*.nix` to this repo to compare & adapt.

1. Rebuild & switch using this repo.

1. Enable vscode server patcher (see <https://github.com/msteen/nixos-vscode-server#enable-the-service>)
  1.1 Enable service: `systemctl --user enable --now auto-fix-vscode-server.service` (it's safe to ignore warning)
  1.2. To prevent GC: `ln -sfT /run/current-system/etc/systemd/user/auto-fix-vscode-server.service ~/.config/systemd/user/auto-fix-vscode-server.service`


## Initial setup (MacOS & other distos)

1. Download nix installer & run it with multi-user mode enabled: `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

1. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes fetch-closure' > ~/.config/nix/nix.conf`

1. On Linux, configure nix by adding to `/etc/nix/nix.conf`.
   No need to do it on Darwin since we already do it nix-darwin (see [configuration.nix](./darwin/mbpapp/configuration.nix))

   ```conf
      keep-outputs = true
      keep-derivations = true
      auto-optimise-store = true

      # allow use of cached builds, require fast internet
      builders-use-substitutes = true

      experimental-features = nix-command flakes fetch-closure
   ```

1. Build `./x home build` and activate `./x home switch`

1. Activate shell by adding `/home/appaquet/.nix-profile/bin/fish` to `/etc/shells`
   and running `chsh -s /home/appaquet/.nix-profile/bin/fish`

1. On MacOS, apply darwin config: `./x darwin build` and `./x darwin witch`
   2. Select a patched nerdfonts font in iTerm2 in order to have icons in neovim.

## Maintenance

- To update flakes, run `./x update`
- To update a specific flake, run `nix flake lock --update-input <the flake>`

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
   set -Ua fish_user_paths /home/appaquet/.local/utils/
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
  - `<leader>s` to save current buffer
  - `<leader>x` to save and then execute current buffer (as long as it's chmod +x)
  - `<leader>z` to execute current visual selection in a shell
  - `<leader>r` to save current buffer and then execute `rsync.sh` in working dir
  - `<leader>q` to close the current buffer (equivalent to `:q`)
  - `<leader>w` to close the current buffer by trying not to messup the layout
  - `<leader><tab>` to switch between tab and spaces
  - `<ctrl>e` to toggle file etree
  - `<ctrl>p` fuzzy finding file
  - `<ctrl>u` fuzzy finding buffers and history
  - `<ctrl>f` riggrep search
  - `<ctrl>o` go back to previous cursor
  - `<ctrl>i` go forward to next cursor
  - `<leader>m` to toggle mouse support (useful to allow select + copy)
  - `<leader>y` to yank to clipboard using [bin/pbcopy](bin/pbcopy) util
  - `<leader>p` to paste from clipboard using [bin/pbpaste](bin/pbpaste) util

- Code / LSP
  - `gD` goto declaration
  - `gd` goto definition
  - `gi` goto implementation
  - `K` hover info
  - `<space>rn` rename symbol
  - `<leader>cc` comment
  - `<leader>cu` uncomment

- Nvim tree
  - In tree
    - `g?` to show help
    - `<ctrl>]` to CD into directory
    - `-` go up one directory
    - `<ctrl>v` Open in vertical split
    - `<ctrl>x` Open in horizontal split
    - `I` Toggle hidden files
    - `r` Rename file
    - `d` Delete file
    - `a` Add file or directory if it ends with `/`
    - `c`, `x`, `v` to copy, cut, paste files
    - `f` to find file, `F` to clear
    - `q` to close tree
    - `E` to expand all, `W` to collapse
  - `<ctrl>e` to toggle file tree

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

## Resources

- <https://nix-community.github.io/home-manager/options.html>
- <https://daiderd.com/nix-darwin/manual/index.html#sec-options>
- <https://nixos.org/manual/nixos/stable/>

