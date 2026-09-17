
default:
    @just --list

fmt *args:
    #!/usr/bin/env bash
    set -euo pipefail
    git ls-files -z --cached --others --exclude-standard -- '*.nix' |
      while IFS= read -r -d '' path; do
        if [[ -e "$path" ]]; then printf '%s\0' "$path"; fi
      done |
      xargs -0 -r nixfmt {{ args }}

check:
    ./x check

# Run every flake check, or only the named ones: `just test pi-session-query`
test *names:
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --impure --raw --expr builtins.currentSystem)

    requested="{{ names }}"
    if [[ -z "$requested" ]]; then
      requested=$(nix eval --json ".#checks.${system}" --apply builtins.attrNames | tr -d '[]"')
      requested=${requested//,/ }
    fi

    attrs=()
    for name in $requested; do
      attrs+=(".#checks.${system}.${name}")
    done

    echo "Running ${#attrs[@]} flake checks for ${system}..."
    exec nix build --no-link -L "${attrs[@]}"

# List the flake checks that `just test` can run
test-list:
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --impure --raw --expr builtins.currentSystem)
    nix eval --json ".#checks.${system}" --apply builtins.attrNames | tr -d '[]"' | tr ',' '\n'

# Build the nixantic instruction package to ./result.
agent-build:
    #!/usr/bin/env bash
    set -euo pipefail

    nix build --out-link result ".#agent-instructions"
    echo "result -> $(readlink result)"

home-check:
    ./x home check

home-build:
    ./x home build

nixos-check:
    ./x nixos check

nixos-build:
    ./x nixos build

darwin-check:
    ./x darwin check

darwin-build:
    ./x darwin build

nixantic-clone:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -d nixantic/.jj ] || [ -d nixantic/.git ]; then
        cd nixantic
        jj git fetch
    else
        git clone git@github.com:appaquet/nixantic.git
        cd nixantic
        jj git init --colocate
        jj b track main@origin
    fi
