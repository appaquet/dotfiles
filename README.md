### Getting started

1. [Install nix](https://nixos.org/download.html)

2. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf`

3. Build `./x build` and activate `./x activate`

4. On MacOS, can also apply darwin config: `./x build-darwin` and `./x activate-darwin`

## MaOS
- [ ] Fonts
- [ ] Fix shell not being set
  - Apparently there is a bug. Should be done in a system activation script (check mat's 1pw stuff)
- [ ] --backup for error about etc shell

```
  system.activationScripts.extraActivation.text = ''
    # For TouchID to work in `op` 1Password CLI, it needs to be at `/usr/local/bin`
    # (Hopefully this requirement will be lifted by 1Password at some point)
    # NOTE we don't install `op` via nix but simply copy the binary
    cp ${pkgs._1password}/bin/op /usr/local/bin/op
  '';
```