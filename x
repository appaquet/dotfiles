#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$ROOT"

HOSTNAME=$(uname -n)
MACHINE_KEY="${USER}@${HOSTNAME}"

HOME_CONFIG=""
if [[ "${MACHINE_KEY}" == "appaquet@ubuntu-nix" ]]; then
    HOME_CONFIG="appaquet@deskapp"
elif [[ "${MACHINE_KEY}" == "appaquet@mbpvmapp.local" ]]; then
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
fetch-vm)
    shift
    rsync -avz --delete appaquet@192.168.2.97:dotfiles/ ~/dotfiles/
    ;;

build)
    shift
    # home-manager build --flake ".#$HOME_CONFIG"
    ${NIX_BUILDER} build ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
    ;;

build-darwin)
    shift
    ${NIX_BUILDER} ".#darwinConfigurations.mbpvmapp.system"
    ;;

activate)
    shift
    # ./result/activate
    home-manager switch --flake ".#$HOME_CONFIG"
    ;;

activate-darwin)
    shift
    ./result/sw/bin/darwin-rebuild switch --flake .
    ;;

check)
    shift
    check_home "appaquet@deskapp"
    check_home "appaquet@mbpapp"
    check_eval ".#darwinConfigurations.mbpvmapp.system"
    ;;

gc)
    shift
    nix-collect-garbage
    ;;

*)
    echo "usage:" >&2
    echo "   $0 build: build current home manager" >&2
    echo "   $0 activate: activate result home manager" >&2
    echo "   $0 build-darwin: build darwin config" >&2
    echo "   $0 activate: activate darwin config" >&2
    echo "   $0 gc: run garbage collection" >&2
    exit 1
    ;;
esac
