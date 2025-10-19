# Nix/NixOS sheet cheat

* Run a uninstalled package: `nix run nixpkgs#cowsay hello world`
* Run a uninstalled package, with fuzzy finding: `nix run nixpkgs#(fzf-nix)`, or `nr`
* Start a shell with a package: `nix shell nixpkgs#ripgrep`
* Start a shell with a package, with fuzzy finding: `nix shell nixpkgs#(fzf-nix)`, or `ns`
