# Generic Nixantic framework recipes.
# Run from inside `nix develop` (or a direnv shell) so `nix` is on PATH.

# Run the repository's Nix flake checks.
check:
    nix flake check --show-trace

# Format the framework sources from the development shell.
fmt:
    git ls-files -z --cached --others --exclude-standard -- '*.nix' | xargs -0 -r nixfmt
