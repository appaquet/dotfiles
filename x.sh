#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd $ROOT

HOSTNAME=$(uname -n)
MACHINE_KEY="${USER}@${HOSTNAME}"

HOME_CONFIG=""
if [[ "${MACHINE_KEY}" == "appaquet@ubuntu-nix" ]]; then
    HOME_CONFIG="x86_64-linux.appaquet@deskapp"
elif [[ "${MACHINE_KEY}" == "appaquet@mbpvmapp.local" ]]; then
    HOME_CONFIG="aarch64-darwin.appaquet@mbpapp"
else
    echo "Non-configured machine (${MACHINE_KEY})"
    exit 1
fi

COMMAND=$1
case $COMMAND in
    build)
        shift
        nix build ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
        ;;

    fetch-vm)
        shift
        rsync -avz appaquet@192.168.2.97:dotfiles/ ~/dotfiles/
        ;;

    activate)
        shift
        ./result/activate
        ;;

    *)
        echo "usage:" >&2
        echo "   $0 build" >&2
        exit 1
        ;;
esac    