#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd $ROOT

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

COMMAND=$1
case $COMMAND in
    fetch-vm)
        shift
        rsync -avz --delete appaquet@192.168.2.97:dotfiles/ ~/dotfiles/
        ;;

    build)
        shift
        # nix build ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
        # home-manager build 
        home-manager build --flake ".#$HOME_CONFIG"
        ;;

    build-darwin)
        shift
        nix build ".#darwinConfigurations.mbpvmapp.system"
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

    *)
        echo "usage:" >&2
        echo "   $0 build: build current home manager" >&2
        echo "   $0 activate: activate result home manager" >&2
        echo "   $0 build-darwin: build darwin config" >&2
        echo "   $0 activate: activate darwin config" >&2
        exit 1
        ;;
esac    