
# Nixified dotfiles

## Initial setup on NixOS

1. Setup NixOS using the installer.

1. Once installed, edit `/etc/nixos/configuration.nix` and rebuild:
   * Enable sshd
   * Change hostname
   * Enable flakes: `nix.settings.experimental-features = [ "flakes" ];`

1. SSH to the machine.

1. Clone this repo recursively (need to setup ssh keys, use a nix-shell with git and neovim).

1. Setup a GitHub personal access token in `~/.config/nix/nix.conf` (see [doc](https://nix.dev/manual/nix/2.18/command-ref/conf-file#conf-access-tokens))

   ```conf
    access-tokens = github.com:<YOUR_TOKEN>
   ```

1. Setup home-manager & activate it.

1. Copy `/etc/nixos/*.nix` to this repo to compare & adapt.

1. Rebuild nixos & switch using this flake.

1. Enable vscode server patcher (see <https://github.com/msteen/nixos-vscode-server#enable-the-service>)
   1. Enable service: `systemctl --user enable --now auto-fix-vscode-server.service` (it's safe to ignore warning)
   1. To prevent GC: `ln -sfT /run/current-system/etc/systemd/user/auto-fix-vscode-server.service ~/.config/systemd/user/auto-fix-vscode-server.service`

## Initial setup on MacOS

1. Download nix installer & run it with multi-user mode enabled: `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

1. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes fetch-closure' > ~/.config/nix/nix.conf`

1. Setup a GitHub personal access token in `~/.config/nix/nix.conf` (see [doc](https://nix.dev/manual/nix/2.18/command-ref/conf-file#conf-access-tokens))

   ```conf
    access-tokens = github.com:<YOUR_TOKEN>
   ```

1. Clone this repo recursively.

1. Install [HomeBrew](https://brew.sh/).

1. Build & activate home.

1. Build & activate darwin.

1. In theory, shell should be changed automatically to fish, but it may not work. Do it manually by
   adding `/home/appaquet/.nix-profile/bin/fish` to `/etc/shells` and running `chsh -s /home/appaquet/.nix-profile/bin/fish`

## Initial setup on Non-NixOS Linux

1. Download nix installer & run it with multi-user mode enabled: `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

1. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes fetch-closure' > ~/.config/nix/nix.conf`

1. Setup a GitHub personal access token in `~/.config/nix/nix.conf` (see [doc](https://nix.dev/manual/nix/2.18/command-ref/conf-file#conf-access-tokens))

   ```conf
    access-tokens = github.com:<YOUR_TOKEN>

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

1. Build & activate home.

1. Switch shell by adding `/home/appaquet/.nix-profile/bin/fish` to `/etc/shells` and running 
   `chsh -s /home/appaquet/.nix-profile/bin/fish`

## Initial setup for Raspberry Pi

### Notes
* <https://github.com/nix-community/raspberry-pi-nix> is used to simplify a lot of the quirks for Rpi.
* Because of the use of `raspberry-pi-nix`, there is no need for a `hardware-configuration.nix` as it's automatically generated & included.
* I use a Mac VM to build the initial SD card to prevent potentially recompiling the whole kernel on a poor Rpi.


### Steps
1. On a UTM NixOS host, create the Rpi NixOS config, and then build and SD card: `nix build '.#nixosConfigurations.piapp.config.system.build.sdImage'`

1. Copy the result image to a SD / USB Stick or Nvme (via USB adapter): `zstdcat result/the-image.img.zstd | dd of=/dev/the-device status=progress`

1. Boot the Rpi and change password.

1. Follow normal procedure to setup home-manager & rebuild NixOS.

## Common

1. The [nix-community](https://app.cachix.org/cache/nix-community) cachix cache may need to be configured and enabled manually before building nixos for the
   first time (`cachix use nix-community`).

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
  
1. `failed: unable to open database file at ... command-not-found`
   As root, run:
   ```
   nix-channel --add https://nixos.org/channels/nixos-unstable nixos
   nix-channel --update
   ```
1. On MacOS, we may end up with an older version of nix installed, leading to flakes
   not working because of use of newer syntax in the lock files (see <https://github.com/LnL7/nix-darwin/issues/931>)

   The fix is to uninstall the old one: `sudo -i nix-env --uninstall nix`

## Cheat sheets

## Nix

* Run a uninstalled package: `nix run nixpkgs#cowsay hello world`
* Run a uninstalled package, with fuzzy finding: `nix run nixpkgs#(fzf-nix)`, or `nr`
* Start a shell with a package: `nix shell nixpkgs#ripgrep`
* Start a shell with a package, with fuzzy finding: `nix shell nixpkgs#(fzf-nix)`, or `ns`

### Fish

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
  * `<ctrl>v`: search env variables
  * `<ctl><alt>n`: search nix packages
  * `<ctl><alt>g`: rigrep search

### Neovim

See [README.nvim.md](./README.nvim.md)

### tmux

* Shortcuts
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

## Resources

* <https://nix-community.github.io/home-manager/options.html>
* <https://daiderd.com/nix-darwin/manual/index.html#sec-options>
* <https://nixos.org/manual/nixos/stable/>
