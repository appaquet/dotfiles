### Getting started

1. [Install nix](https://nixos.org/download.html)

2. Enable flakes: `mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf`

3. Build `./x build` and activate `./x activate`

4. On MacOS, can also apply darwin config: `./x build-darwin` and `./x activate-darwin`