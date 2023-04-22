#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$ROOT"

HOSTNAME=$(uname -n | tr '[:upper:]' '[:lower:] | sed 's/\.local//'')
MACHINE_KEY="${USER}@${HOSTNAME}"

HOME_CONFIG=""
if [[ "${MACHINE_KEY}" == "appaquet@deskapp" || "${MACHINE_KEY}" == "appaquet@ubuntu-nix" ]]; then
    HOME_CONFIG="appaquet@deskapp"
elif [[ "${MACHINE_KEY}" == "appaquet@mbpapp" || "${MACHINE_KEY}" == "appaquet@mbpvmapp" ]]; then
    HOME_CONFIG="appaquet@mbpapp"
else
    echo "Non-configured machine (${MACHINE_KEY})"
    exit 1
fi

sudo echo # prime pw for nom redirects to work

NIX_BUILDER="nix"
NOM_PIPE="tee"
if [[ -x ~/.nix-profile/bin/nom ]]; then
    NIX_BUILDER="nom"
    NOM_PIPE="nom"
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
    check_eval ".#darwinConfigurations.mbpapp.system"
    ;;

home)
    shift
    SUBCOMMAND=$1
    case $SUBCOMMAND in
    build)
        shift
        home-manager build --flake ".#$HOME_CONFIG" |& ${NOM_PIPE}
        ;;
    activate)
        shift
        home-manager switch --flake ".#$HOME_CONFIG" |& ${NOM_PIPE}
        ;;
    *)
        echo "$0 $COMMAND build: build home" >&2
        echo "$0 $COMMAND activate: activate/switch home" >&2
        exit 1
        ;;
    esac
    ;;

darwin)
    shift
    SUCOMMAND=$1
    case $SUBCOMMAND in
    build)
        shift
        ${NIX_BUILDER} build ".#darwinConfigurations.mbpapp.system"
        ;;
    activate)
        shift
        ./result/sw/bin/darwin-rebuild switch --flake .
        ;;
    *)
        echo "$0 $COMMAND build: build home" >&2
        echo "$0 $COMMAND activate: activate/switch home" >&2
        exit 1
        ;;
    esac
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
    echo "$0 check: check eval homes & darwin" >&2
    echo "$0 home: home manager sub commands" >&2
    echo "$0 darwin: darwin sub commands" >&2
    echo "$0 update: update nix channels" >&2
    echo "$0 gc: run garbage collection" >&2
    echo "$0 fetch-deskapp: fetch latest dotfiles from deskapp" >&2
    exit 1
    ;;
esac
