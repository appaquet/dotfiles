### Getting started

1. Install nix
2. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf`
3. Edit home.nix to reflect your username (and flake.nix since it'll look for it there)
4. Build derivation: `nix build .#homeConfigurations.jdoe.activationPackage`  (generates a `result` symlink to the built package) then activate it (`./result/activate`)

4.1 Or, you could use home-manager through nix run: `nix run home-manager -- switch --flake .` - they are equivalent
