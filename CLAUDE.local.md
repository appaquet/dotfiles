docs are symlinked to secrets sub-module. It's normal if they aren't visible in dotfiles repo.

## Building & Testing

Use `./x` script for building and evaluating nix configurations:

- `./x nixos check` - Eval nixos config for current host
- `./x nixos build` - Build nixos config
- `./x home check` - Eval home-manager config
- `./x home build` - Build home-manager config
- `HOST=deskapp ./x nixos check` - Check specific host

For quick iteration, use `check` first (fast eval) before `build`.
