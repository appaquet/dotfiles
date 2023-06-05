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

prime_sudo() {
    sudo echo # prime pw for nom redirects to work
}

copy_files() {
    local host="$1"
    local file
    for file in $(find "${ROOT}/files/${host}" -type f); do
        local target_file="${file/${ROOT}\/files\/${host}/}"
        local target_path="${target_file}"

        echo "Copy ${file} to ${target_path}"

        # if outside of home, use sudo
        if [[ "${target_path}" != "${HOME}/"* ]]; then
            sudo mkdir -p "$(dirname "${target_path}")"
            sudo cp "${file}" "${target_path}"
        else
            mkdir -p "$(dirname "${target_path}")"
            cp "${file}" "${target_path}"
        fi
    done
}

COMMAND=$1
case $COMMAND in
home)
    shift
    SUBCOMMAND=$1
    case $SUBCOMMAND in
    check)
        shift
        check_home $HOME_CONFIG
        ;;
    build)
        shift
        ${NIX_BUILDER} build ".#homeConfigurations.${HOME_CONFIG}.activationPackage" 2>&1 | ${NOM_PIPE}
        ;;
    switch)
        shift
        ./result/activate
        ;;
    *)
        echo "$0 $COMMAND build: build home" >&2
        echo "$0 $COMMAND switch: switch home" >&2
        exit 1
        ;;
    esac
    ;;

darwin)
    shift
    SUBCOMMAND=$1
    case $SUBCOMMAND in
    build)
        shift
        ${NIX_BUILDER} build ".#darwinConfigurations.mbpapp.system"
        ;;
    check)
        shift
        check_eval ".#darwinConfigurations.mbpapp.system"
        ;;
    switch)
        shift
        ./result/sw/bin/darwin-rebuild switch --flake .
        ;;
    *)
        echo "$0 $COMMAND build: build home" >&2
        echo "$0 $COMMAND switch: switch home" >&2
        exit 1
        ;;
    esac
    ;;

check)
    shift
    check_home "appaquet@deskapp"
    check_home "appaquet@mbpapp"
    check_eval ".#darwinConfigurations.mbpapp.system"
    ;;

update)
    shift
    PACKAGE="$1"
    if [[ -z "$PACKAGE" ]]; then
      nix-channel --update
      nix flake update
    else
      nix flake lock --update-input $PACKAGE
    fi
    ;;

link)
    shift
    if [[ ! -d "${ROOT}/files/${HOSTNAME}" ]]; then
        echo "No files for ${HOSTNAME}"
        exit 1
    fi

    prime_sudo
    copy_files "$HOSTNAME"
    ;;

gc)
    shift
    echo "Garbage collecting..."

    nix-collect-garbage --delete-older-than "14d"
    home-manager expire-generations "-14 days"

    # Cleaning as root collects more stuff as well
    # See https://www.reddit.com/r/NixOS/comments/10107km/how_to_delete_old_generations_on_nixos/?s=8
    ncg=$(which nix-collect-garbage)
    sudo ${ncg} -d

    ;;

optimize)
    shift
    echo "Optimizing store..."
    nix store optimise
    ;;

fetch-deskapp)
    shift
    rsync -avz --delete appaquet@deskapp.tailscale:dotfiles/ ~/dotfiles/
    ;;

*)
    echo "$0 home: home manager sub commands" >&2
    echo "$0 darwin: darwin sub commands" >&2
    echo "$0 check: eval home & darwin configs for all hosts" >&2
    echo "$0 update: update nix channels" >&2
    echo "$0 link: link system files" >&2
    echo "$0 gc: run garbage collection" >&2
    echo "$0 optimize: optimize store" >&2
    echo "$0 fetch-deskapp: fetch latest dotfiles from deskapp" >&2
    exit 1
    ;;
esac
