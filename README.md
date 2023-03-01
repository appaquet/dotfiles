
# Nixified dotfiles

## TODO

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

6. Build `./x build` and activate `./x activate`
   1. On Linux, you may have to change shell to fish: `usermod -s /home/$USER/.nix-profile/bin/fish $USER`

7. On MacOS, can also apply darwin config: `./x build-darwin` and `./x activate-darwin`
   1. Activate shell by adding `/usr/local/bin/fish` to `/etc/shells` and running `chsh -s /usr/local/bin/fish`

## Troubleshooting

1. It seems that when switching to newer fish, the paths weren't properly set.
   They should look like:
     - /nix/var/nix/profiles/default/bin
     - /home/appaquet/.nix-profile/bin

## Cheatsheet

### Fish

- Paths: fish uses `fish_user_paths` to define paths and can be persisted when using "universal variables" (set with `-U`).
  - To add a path: `set -Ua fish_user_paths /some/new/path`
  - To list current paths: `echo $fish_user_paths | tr " " "\n" | nl`
  - To remove a path: `set --erase fish_user_paths[NUMBER AS LISTED STARTING AT 1]`
