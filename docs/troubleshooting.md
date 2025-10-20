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

## Cachix Binary Cache Not Trusted

**Problem**: When building a NixOS configuration that uses nvmd/nixos-raspberrypi or other cachix-hosted packages, you may see warnings like:

```
warning: ignoring substitute for '/nix/store/...' from 'https://nixos-raspberrypi.cachix.org',
as it's not signed by any of the keys in 'trusted-public-keys'
```

This causes Nix to rebuild packages from source instead of using pre-built binaries, which can be very slow (especially for the kernel).

**Cause**: The cachix cache isn't in your system's trusted substituters and public keys yet. On systems with read-only `/etc/nix/nix.conf` (like those managed by this flake), you can't just add the cache and rebuild - that would require rebuilding first to update the config.

**Temporary Solution**: Use command-line flags to add the cache for a single build:

```bash
sudo nixos-rebuild switch --flake .#piapp \
  --option extra-substituters "https://cache.nixos.org/ https://nix-community.cachix.org https://nixos-raspberrypi.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
```

**Permanent Fix**: Add the cache to `nixos/cachix.nix` before your first build, or after using the temporary solution above. The cache configuration should already be in the file if you're using nvmd/nixos-raspberrypi.
