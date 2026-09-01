
default:
    @just --list

fmt:
    ./x fmt

check:
    ./x check

agent-build:
    ./x agent build

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
