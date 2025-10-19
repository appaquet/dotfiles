# Troubleshooting

* It seems that when switching to newer fish, the paths weren't properly set.
   On top of that, it may be shadowed by a global fish path too.
   Reset fish paths with:

   ```bash
   set -ge fish_user_paths
   set -Ua fish_user_paths /nix/var/nix/profiles/default/bin
   set -Ua fish_user_paths /home/appaquet/.nix-profile/bin
   set -Ua fish_user_paths /home/appaquet/.local/utils/
   ```
  
* `failed: unable to open database file at ... command-not-found`
   As root, run:

    ```bash
     nix-channel --add https://nixos.org/channels/nixos-unstable nixos
     nix-channel --update
     ```

* On MacOS, we may end up with an older version of nix installed, leading to flakes
   not working because of use of newer syntax in the lock files (see <https://github.com/LnL7/nix-darwin/issues/931>)

   The fix is to uninstall the old one: `sudo -i nix-env --uninstall nix`
