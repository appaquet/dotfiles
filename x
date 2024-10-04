#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$ROOT"

HOSTNAME=$(uname -n | tr '[:upper:]' '[:lower:] | sed 's/\.local//'')

if [[ -z "${MACHINE_KEY}" ]]; then
    MACHINE_KEY="${USER}@${HOSTNAME}"
fi

HOME_CONFIG=""
NIXOS=0
if [[ "${MACHINE_KEY}" == "appaquet@deskapp"* || "${MACHINE_KEY}" == "appaquet@nixos"* ]]; then
    HOME_CONFIG="appaquet@deskapp"
    HOSTNAME="deskapp"
    NIXOS=1

elif [[ "${MACHINE_KEY}" == "appaquet@nixapp"* ]]; then
    HOME_CONFIG="appaquet@nixapp"
    HOSTNAME="nixapp"
    NIXOS=1

elif [[ "${MACHINE_KEY}" == "appaquet@servapp"* ]]; then
    HOME_CONFIG="appaquet@servapp"

elif [[ "${MACHINE_KEY}" == "appaquet@mbpapp"* || "${MACHINE_KEY}" == "appaquet@mbpvmapp"* ]]; then
    HOME_CONFIG="appaquet@mbpapp"
fi

NIX_BUILDER="nix"
NOM_PIPE="tee"
if [[ -x ~/.nix-profile/bin/nom ]]; then
    NIX_BUILDER="nom"
    NOM_PIPE="nom"
fi

if [[ ! -f "$ROOT/secrets/flake.nix" ]]; then
    echo "Secrets aren't checked out. Make sure you checkout & decrypt them after activation"
    sleep 2
fi

SECRETS_CHANGED=$(git diff --submodule=log secrets | grep "Submodule" || true)
if [[ -n "$SECRETS_CHANGED" ]]; then
    echo "Secrets submodule has changes. Make sure to update prior to building"
    sleep 1
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
    find "${ROOT}/files/${host}" -type f | while read -r file; do
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

    if [[ -z "$HOME_CONFIG" ]]; then
        echo "No home configuration for ${MACHINE_KEY}"
        exit 1
    fi

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

        GENERATION="${1:-}"
        if [[ -n "$GENERATION" ]]; then
            GEN_PATH=$(home-manager generations | grep "id ${GENERATION}" | awk '{print $7}')
            if [[ -z "$GEN_PATH" ]]; then
                echo "Generation $GENERATION not found"
                exit 1
            fi

            echo "Activating generation $GENERATION at $GEN_PATH"
            $GEN_PATH/activate
        else
            echo "Activating latest generation"
            ./result/activate
        fi
        ;;
    diff)
        shift
        nvd diff ~/.local/state/nix/profiles/home-manager ./result
        ;;
    tree)
        shift
        nix-tree ~/.local/state/nix/profiles/home-manager
        ;;
    generations)
        shift
        home-manager generations
        ;;
    diff-generations)
        shift
        nix profile diff-closures --profile ~/.local/state/nix/profiles/home-manager
        ;;
    *)
        echo "$0 $COMMAND check: check home" >&2
        echo "$0 $COMMAND build: build home" >&2
        echo "$0 $COMMAND switch: switch home" >&2
        echo "$0 $COMMAND diff: diff last build with current" >&2
        echo "$0 $COMMAND tree: show home tree" >&2
        echo "$0 $COMMAND generations: list generations" >&2
        echo "$0 $COMMAND diff-generations: diff last generations" >&2
        exit 1
        ;;
    esac
    ;;

darwin)
    shift
    SUBCOMMAND=$1
    case $SUBCOMMAND in
    check)
        shift
        check_eval ".#darwinConfigurations.mbpapp.system"
        ;;
    build)
        shift
        ${NIX_BUILDER} build ".#darwinConfigurations.mbpapp.system"
        ;;
    switch)
        shift
        ./result/sw/bin/darwin-rebuild switch --flake .
        ;;
    tree)
        shift
        nix-tree ~/.nix-profile
        ;;
    *)
        echo "$0 $COMMAND check: check home" >&2
        echo "$0 $COMMAND build: build home" >&2
        echo "$0 $COMMAND switch: switch home" >&2
        echo "$0 $COMMAND tree: show home tree" >&2
        exit 1
        ;;
    esac
    ;;

nixos)
    shift
    SUBCOMMAND=$1
    case $SUBCOMMAND in
    check)
        shift
        check_eval ".#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel"
        ;;
    build)
        shift
        nixos-rebuild build --flake ".#${HOSTNAME}" 2>&1 | ${NOM_PIPE}
        ;;
    boot)
        shift
        nixos-rebuild boot --flake ".#${HOSTNAME}" 2>&1 | ${NOM_PIPE}
        ;;
    switch)
        shift

        prime_sudo
        GENERATION="${1:-}"
        if [[ -n "$GENERATION" ]]; then
            GEN_PATH="/nix/var/nix/profiles/system-${GENERATION}-link"
            if [[ ! -d "$GEN_PATH" ]]; then
                echo "Generation $GENERATION not found"
                exit 1
            fi

            echo "Activating generation $GENERATION at $GEN_PATH"
            sudo $GEN_PATH/activate
        else
            echo "Activating latest generation"
            sudo nixos-rebuild switch --flake ".#${HOSTNAME}" 2>&1 | ${NOM_PIPE}
        fi
        ;;
    diff)
        shift
        nvd diff /run/current-system result
        ;;
    tree)
        shift
        nix-tree /run/current-system
        ;;
    kernel-versions)
        shift
        BOOTED=$(readlink /run/booted-system/{initrd,kernel,kernel-modules} | tr '\n' ' ')
        CURRENT=$(readlink /run/current-system/{initrd,kernel,kernel-modules} | tr '\n' ' ')
        RESULT=$(readlink ./result/{initrd,kernel,kernel-modules} | tr '\n' ' ')
        HAS_DIFF=0

        if [[ "$BOOTED" != "$CURRENT" ]]; then
            HAS_DIFF=1
            echo "Booted kernel isn't the same as last generation"
            echo "  Booted: $BOOTED"
            echo "  Current: $CURRENT"
            echo " "
        fi

        if [[ "$BOOTED" != "$RESULT" ]]; then
            HAS_DIFF=1
            echo "Booted kernel isn't the same as the one in ./result"
            echo "  Booted: $BOOTED"
            echo "  Result: $RESULT"
        fi

        if [[ "$HAS_DIFF" -eq 0 ]]; then
            echo "Kernel versions are consistent"
        fi

        ;;
    generations)
        shift
        nix profile history --profile /nix/var/nix/profiles/system
        ;;
    *)
        echo "$0 $COMMAND check: check nixos" >&2
        echo "$0 $COMMAND build: build nixos" >&2
        echo "$0 $COMMAND boot: rebuild boot (remove old gens)" >&2
        echo "$0 $COMMAND diff: diff nixos" >&2
        echo "$0 $COMMAND tree: show nixos tree" >&2
        echo "$0 $COMMAND kernel-versions: show kernel versions" >&2
        echo "$0 $COMMAND generations: diff nixos" >&2
        echo "$0 $COMMAND switch: switch nixos" >&2
        exit 1
        ;;
    esac
    ;;

check)
    shift
    check_home "appaquet@deskapp"
    check_eval ".#nixosConfigurations.deskapp.config.system.build.toplevel"

    check_home "appaquet@servapp"

    check_home "appaquet@mbpapp"
    check_eval ".#darwinConfigurations.mbpapp.system"

    check_home "appaquet@nixapp"
    check_eval ".#nixosConfigurations.nixapp.config.system.build.toplevel"
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
    sudo ${ncg} -d --delete-older-than "14d"

    if [[ "$NIXOS" -eq 1 ]]; then
        echo "Call x nixos boot to remove old generations from boot"
    fi
    ;;

fmt)
    shift
    nixpkgs-fmt "${@}" .
    ;;

optimize)
    shift
    echo "Optimizing store..."
    nix store optimise
    ;;

fetch-deskapp)
    shift
    rsync -avz --delete appaquet@deskapp.n3x.net:dotfiles/ ~/dotfiles/
    ;;

*)
    echo "$0 home: home manager sub commands" >&2
    echo "$0 darwin: darwin sub commands" >&2
    echo "$0 nixos: nixos sub commands" >&2
    echo "$0 check: eval home & nixos & darwin configs for all hosts" >&2
    echo "$0 update: update nix channels" >&2
    echo "$0 link: link system files" >&2
    echo "$0 gc: run garbage collection" >&2
    echo "$0 fmt: format nix files" >&2
    echo "$0 optimize: optimize store" >&2
    echo "$0 fetch-deskapp: fetch latest dotfiles from deskapp" >&2
    exit 1
    ;;
esac
