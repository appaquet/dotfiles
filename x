#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$ROOT"

HOSTNAME=$(uname -n | tr '[:upper:]' '[:lower:]')
MACHINE_KEY="${USER}@${HOSTNAME}"

HOME_CONFIG=""
if [[ "${MACHINE_KEY}" == "appaquet@deskapp" || "${MACHINE_KEY}" == "appaquet@ubuntu-nix" ]]; then
    HOME_CONFIG="appaquet@deskapp"
elif [[ "${MACHINE_KEY}" == "appaquet@mbpapp.local" || "${MACHINE_KEY}" == "appaquet@mbpvmapp.local" ]]; then
    HOME_CONFIG="appaquet@mbpapp"
else
    echo "Non-configured machine (${MACHINE_KEY})"
    exit 1
fi

NIX_BUILDER="nix"
if [[ -x ~/.nix-profile/bin/nom ]]; then
    NIX_BUILDER="nom"
fi

check_eval() {
    nix eval --raw "${1}"
}

check_home() {
    echo "Checking home ${1}"
    check_eval ".#homeConfigurations.${1}.activationPackage"
}

COMMAND=$1
case $COMMAND in
check)
    shift
    check_home "appaquet@deskapp"
    check_home "appaquet@mbpapp"
    check_eval ".#darwinConfigurations.mbpvmapp.system"
    ;;

build)
    shift
    # home-manager build --flake ".#$HOME_CONFIG"
    # home-manager switch --flake ".#$HOME_CONFIG"
    ${NIX_BUILDER} build ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
    ;;

build-darwin)
    shift
    ${NIX_BUILDER} build ".#darwinConfigurations.mbpapp.system"
    ;;

activate)
    shift
    ./result/activate
    ;;

activate-darwin)
    shift
    ./result/sw/bin/darwin-rebuild switch --flake .
    ;;

update)
    shift
    nix-channel --update
    nix flake update
    ;;

gc)
    shift
    nix-collect-garbage
    ;;

fetch-deskapp)
    shift
    rsync -avz --delete appaquet@deskapp.tailscale:dotfiles/ ~/dotfiles/
    ;;

*)
    echo "usage:" >&2
    echo "   $0 check: check eval homes & darwin" >&2
    echo "   $0 build: build current home manager" >&2
    echo "   $0 build-darwin: build darwin config" >&2
    echo "   $0 activate: activate result home manager" >&2
    echo "   $0 activate-darwin: activate darwin config" >&2
    echo "   $0 update: update nix channels" >&2
    echo "   $0 gc: run garbage collection" >&2
    echo "   $0 fetch-deskapp: fetch latest dotfiles from deskapp" >&2
    exit 1
    ;;
esac
