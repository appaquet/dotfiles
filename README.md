
# Nixified dotfiles

## Initial setup

1. [Install nix](https://nixos.org/download.html)

2. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf`

3. Build `./x build` and activate `./x activate`
   1. On Linux, you may have to change shell to fish: `usermod -s /home/$USER/.nix-profile/bin/fish $USER`

4. On MacOS, can also apply darwin config: `./x build-darwin` and `./x activate-darwin`
   1. Activate shell by adding `/usr/local/bin/fish` to `/etc/shells` and running `chsh -s /usr/local/bin/fish`
