
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

# Refresh the caddy plugin hash in the current host's nixos/<host>/caddy.nix from the build error.
caddy-hash:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob

    system=$(nix eval --impure --raw --expr builtins.currentSystem)

    identity="${HOST:-$(uname -n | tr '[:upper:]' '[:lower:]' | sed 's/\.local$//')}"

    # Prefer the machine's own host; otherwise take the first caddy host on this platform, since a host
    # with the same platform resolves the same nixpkgs and therefore the same hash.
    host=""
    if [[ -f "nixos/${identity}/caddy.nix" ]]; then
      host="$identity"
    else
      for file in nixos/*/caddy.nix; do
        candidate=$(basename "$(dirname "$file")")
        if ! candidate_system=$(nix eval --raw ".#nixosConfigurations.${candidate}.config.nixpkgs.hostPlatform.system" 2>/dev/null); then
          echo "skipping nixosConfigurations.${candidate}: evaluation failed" >&2
          continue
        fi
        if [[ "$candidate_system" == "$system" ]]; then
          host="$candidate"
          break
        fi
      done
    fi

    if [[ -z "$host" ]]; then
      echo "no nixos/<host>/caddy.nix for ${identity} or for ${system}" >&2
      exit 1
    fi

    file="nixos/${host}/caddy.nix"
    attr=".#nixosConfigurations.${host}.config.services.caddy.package.src"
    old=$(nix eval --raw "${attr}.outputHash")
    log=$(mktemp)
    trap 'rm -f "$log"' EXIT

    echo "computing the caddy plugin hash for ${host} (declared ${old})"

    # A stale hash still builds while the store holds the artifact of an earlier toolchain, so force a
    # rebuild against a fake hash to get the value this machine really produces.
    if nix build --impure --no-link --expr "
      let
        f = builtins.getFlake \"path:${PWD}\";
        src = f.nixosConfigurations.${host}.config.services.caddy.package.src;
      in src.overrideAttrs (_: { outputHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"; })
    " >"$log" 2>&1; then
      echo "the fake-hash build succeeded, which should not happen" >&2
      exit 1
    fi

    new=$(sed -nE 's/^[[:space:]]*got:[[:space:]]+(sha256-[A-Za-z0-9+/=]+)$/\1/p' "$log")
    found=$(printf '%s\n' "$new" | grep -c . || true)
    if [[ "$found" -ne 1 ]]; then
      echo "expected exactly one hash in the build output, found ${found}:" >&2
      cat "$log" >&2
      exit 1
    fi

    if [[ "$new" == "$old" ]]; then
      echo "caddy plugin hash is up to date"
      exit 0
    fi

    if ! grep -qF "$old" "$file"; then
      echo "${file} does not contain the declared hash ${old}" >&2
      exit 1
    fi

    sed -i "s|${old}|${new}|g" "$file"
    echo "updated ${file}: ${old} -> ${new}"

    nix build --no-link "$attr"
    echo "confirmed ${new}"

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
