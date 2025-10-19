# Installation

## NixOS setup

1. Setup NixOS using the installer

1. Start a neovim shell
   `nix shell --extra-experimental-features nix-command --extra-experimental-features flakes nixpkgs#neovim`

1. Edit configurations:
   `sudo nvim /etc/nixos/configuration.nix`:
   * Enable sshd
   * Change hostname
   * Enable flakes: `nix.settings.experimental-features = [ "flakes" ];`

1. Rebuild NixOS
   `sudo nixos-rebuild switch`

1. SSH to the machine

1. Start neovim & git shells
   `nix shell --extra-experimental-features nix-command --extra-experimental-features flakes nixpkgs#neovim nixpkgs#git`

1. Setup a GitHub personal access token in `~/.config/nix/nix.conf`
   (see [doc](https://nix.dev/manual/nix/2.18/command-ref/conf-file#conf-access-tokens))

   ```conf
    access-tokens = github.com:<YOUR_TOKEN>
   ```

1. Setup SSH keys

1. Clone repo: `git clone --recursive git@github.com:appaquet/dotfiles.git`

1. Setup home-manager & activate it.

1. Copy `/etc/nixos/*.nix` to this repo to compare & adapt.

1. Rebuild NixOS & switch using this flake.

## MacOS setup

1. Download nix installer & run it with multi-user mode enabled:
   `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

1. Enable flakes:
   `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes fetch-closure' > ~/.config/nix/nix.conf`

1. Setup a GitHub personal access token in `~/.config/nix/nix.conf`
   (see [doc](https://nix.dev/manual/nix/2.18/command-ref/conf-file#conf-access-tokens))

   ```conf
    access-tokens = github.com:<YOUR_TOKEN>
   ```

1. Clone repo: `git clone --recursive git@github.com:appaquet/dotfiles.git`

1. Install [HomeBrew](https://brew.sh/).

1. Build & activate home.

1. Build & activate darwin.

1. In theory, shell should be changed automatically to fish, but it may not work. Do it manually by
   adding `/home/appaquet/.nix-profile/bin/fish` to `/etc/shells` and running `chsh -s /home/appaquet/.nix-profile/bin/fish`

## Initial setup on Non-NixOS Linux

1. Download nix installer & run it with multi-user mode enabled:
   `curl -L https://nixos.org/nix/install | sh -s -- --daemon`

1. Enable flakes:
   `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes fetch-closure' > ~/.config/nix/nix.conf`

1. Setup a GitHub personal access token in `~/.config/nix/nix.conf`
   (see [doc](https://nix.dev/manual/nix/2.18/command-ref/conf-file#conf-access-tokens))

   ```conf
    access-tokens = github.com:<YOUR_TOKEN>
   ```

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

1. Clone repo, configure home & activate it.

1. Switch shell by adding `/home/appaquet/.nix-profile/bin/fish` to `/etc/shells` and running
   `chsh -s /home/appaquet/.nix-profile/bin/fish`

## Initial setup for Raspberry Pi

### Notes

* <https://github.com/nix-community/raspberry-pi-nix> is used to simplify a lot of the quirks for Rpi.
* Because of the use of `raspberry-pi-nix`, there is no need for a `hardware-configuration.nix` as it's automatically generated & included.
* I use a Mac VM to build the initial SD card to prevent potentially recompiling the whole kernel on a poor Rpi.

### Steps

1. On a UTM NixOS host, create the Rpi NixOS config, and then build and SD card:
   `nix build '.#nixosConfigurations.piapp.config.system.build.sdImage'`

1. Copy the result image to a SD / USB Stick or Nvme (via USB adapter):
   `zstdcat result/the-image.img.zstd | dd of=/dev/the-device status=progress`

1. Boot the Rpi and change password.

1. Follow normal procedure to setup home-manager & rebuild NixOS.

## Common

1. The [nix-community](https://app.cachix.org/cache/nix-community) cachix cache may need to be configured and enabled manually before building nixos for the
   first time (`cachix use nix-community`).
