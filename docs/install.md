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

## Non-NixOS Linux

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
   No need to do it on Darwin since we already do it nix-darwin
   (see [configuration.nix](./darwin/mbpapp/configuration.nix))

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

## NixOS on Raspberry Pi

* <https://github.com/nvmd/nixos-raspberrypi> is used to provide comprehensive Raspberry Pi support with optimized packages and active maintenance.
* I use a Mac VM to build the initial SD card to prevent potentially recompiling the whole kernel on a poor Rpi.
* A cachix cache is used to speed up builds.
* Check [this](https://github.com/appaquet/dotfiles/blob/2e5cb2d78cc92ca77b1c33aee0f659027612bbdc/docs/rpi5-migration.md) for more details on the setup.

### Building SD Card Image

1. On a UTM NixOS host, use the `-sdimage` configuration to build an SD card:

   ```bash
   MACHINE_KEY=appaquet@piapp ./x nixos sdimage
   ```

1. Copy the result image to a SD card:

   ```bash
   zstdcat result/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress
   ```

### Initial Boot and Configuration

1. Boot the RPi from SD card and change password.

1. **NVMe Migration** (Optional): If using NVMe, copy system to NVMe and update boot:

   ```bash
   # Format NVMe drive
   sudo fdisk /dev/nvme0n1  # Create partitions matching SD layout

   # Copy system to NVMe
   sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 bs=4M status=progress

   # NVMe boot is handled automatically by nvmd/nixos-raspberrypi
   ```

1. Generate hardware configuration on the running system:

   ```bash
   sudo nixos-generate-config --show-hardware-config
   ```

   Copy the output to `nixos/piapp/hardware-configuration.nix` with `lib.mkDefault` for all filesystem options.

1. Follow normal procedure to setup home-manager & rebuild NixOS.
