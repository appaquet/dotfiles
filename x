#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$ROOT"

HOSTNAME=$(uname -n | tr '[:upper:]' '[:lower:] | sed 's/\.local//'')

LOCAL_MACHINE_KEY="${USER}@${HOSTNAME}"
if [[ -z "${MACHINE_KEY}" ]]; then
  MACHINE_KEY="${LOCAL_MACHINE_KEY}"
fi

HOME_CONFIG=""
if [[ "${MACHINE_KEY}" == "appaquet@deskapp"* ]]; then
  HOME_CONFIG="appaquet@deskapp"
  HOSTNAME="deskapp"
  OS_TYPE="nixos"

elif [[ "${MACHINE_KEY}" == "appaquet@servapp"* ]]; then
  HOME_CONFIG="appaquet@servapp"
  HOSTNAME="servapp"
  OS_TYPE="nixos"

elif [[ "${MACHINE_KEY}" == "appaquet@utm"* ]]; then
  HOME_CONFIG="appaquet@utm"
  HOSTNAME="utm"
  OS_TYPE="nixos"

elif [[ "${MACHINE_KEY}" == "appaquet@piapp"* ]]; then
  HOME_CONFIG="appaquet@piapp"
  HOSTNAME="piapp"
  OS_TYPE="nixos"

elif [[ "${MACHINE_KEY}" == "appaquet@piprint"* ]]; then
  HOME_CONFIG="appaquet@piprint"
  HOSTNAME="piprint"
  OS_TYPE="nixos"

elif [[ "${MACHINE_KEY}" == "appaquet@piups"* ]]; then
  HOME_CONFIG="appaquet@piups"
  HOSTNAME="piups"
  OS_TYPE="nixos"

elif [[ "${MACHINE_KEY}" == "appaquet@mbpapp"* || "${MACHINE_KEY}" == "appaquet@mbpvmapp"* ]]; then
  HOME_CONFIG="appaquet@mbpapp"
  OS_TYPE="darwin"
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

check_nixos() {
  echo "Checking nixos ${1}"
  check_eval ".#nixosConfigurations.${1}.config.system.build.toplevel"
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
h | home)
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
  b | build)
    shift
    ${NIX_BUILDER} build "$@" ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
    ;;
  s | switch)
    shift

    GENERATION="${1:-}"
    if [[ -n "$GENERATION" ]]; then
      GEN_PATH=$(home-manager generations | grep "id ${GENERATION}" | awk '{print $7}')
      if [[ -z "$GEN_PATH" ]]; then
        echo "Generation $GENERATION not found"
        exit 1
      fi

      echo "Activating generation $GENERATION at $GEN_PATH"
      "$GEN_PATH"/activate
    else
      echo "Activating latest generation"
      ./result/activate
    fi
    ;;
  bs | build-switch)
    shift
    "$0" home build "$@" && "$0" home switch
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
    echo "$0 $COMMAND build (b): build home" >&2
    echo "$0 $COMMAND switch (s): switch home" >&2
    echo "$0 $COMMAND build-switch (bs): build and switch" >&2
    echo "$0 $COMMAND diff: diff last build with current" >&2
    echo "$0 $COMMAND tree: show home tree" >&2
    echo "$0 $COMMAND generations: list generations" >&2
    echo "$0 $COMMAND diff-generations: diff last generations" >&2
    exit 1
    ;;
  esac
  ;;

d | darwin)
  shift
  SUBCOMMAND=$1
  case $SUBCOMMAND in
  check)
    shift
    check_eval ".#darwinConfigurations.mbpapp.system"
    ;;
  b | build)
    shift
    ${NIX_BUILDER} build "$@" ".#darwinConfigurations.mbpapp.system"
    ;;
  s | switch)
    shift
    sudo ./result/sw/bin/darwin-rebuild switch --flake .
    ;;
  bs | build-switch)
    shift
    "$0" darwin build "$@" && "$0" darwin switch
    ;;
  diff)
    shift
    nvd diff /run/current-system result
    ;;
  tree)
    shift
    nix-tree ~/.nix-profile
    ;;
  *)
    echo "$0 $COMMAND check: check darwin" >&2
    echo "$0 $COMMAND build (b): build darwin" >&2
    echo "$0 $COMMAND switch (s): switch darwin" >&2
    echo "$0 $COMMAND build-switch (bs): build and switch" >&2
    echo "$0 $COMMAND diff: diff last build with current" >&2
    echo "$0 $COMMAND tree: show darwin tree" >&2
    exit 1
    ;;
  esac
  ;;

n | nixos)
  shift
  SUBCOMMAND=$1
  case $SUBCOMMAND in
  check)
    shift
    check_eval ".#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel"
    ;;
  b | build)
    shift
    ${NIX_BUILDER} build "$@" ".#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel"
    ;;
  sdimage)
    shift
    echo "Building SD card image for ${HOSTNAME}..."
    ${NIX_BUILDER} build ".#nixosConfigurations.${HOSTNAME}.config.system.build.sdImage"

    if [[ -L ./result ]]; then
      IMAGE=$(find ./result -name "*.img.zst" -o -name "*.img" | head -1)
      if [[ -n "$IMAGE" ]]; then
        echo ""
        echo "SD image built successfully!"
        echo "Image: $IMAGE"
        echo ""
        echo "To write to SD card:"
        if [[ "$IMAGE" == *.zst ]]; then
          echo "  zstdcat $IMAGE | sudo dd of=/dev/sdX bs=4M status=progress"
        else
          echo "  sudo dd if=$IMAGE of=/dev/sdX bs=4M status=progress"
        fi
      fi
    fi
    ;;
  boot)
    shift

    prime_sudo
    sudo nixos-rebuild boot --flake ".#${HOSTNAME}"
    ;;
  s | switch)
    shift

    read -r -p "Are you sure you want to switch now. Switching on next boot is recommended (y/n): " confirm
    if [[ "$confirm" == [yY] ]]; then
      echo "Switching now..."
    else
      echo "Aborting switch"
      exit 1
    fi

    prime_sudo
    GENERATION="${1:-}"
    if [[ -n "$GENERATION" ]]; then
      GEN_PATH="/nix/var/nix/profiles/system-${GENERATION}-link"
      if [[ ! -d "$GEN_PATH" ]]; then
        echo "Generation $GENERATION not found"
        exit 1
      fi

      echo "Activating generation $GENERATION at $GEN_PATH"
      sudo "$GEN_PATH"/activate
    else
      echo "Activating latest generation"
      sudo nixos-rebuild switch --flake ".#${HOSTNAME}"
    fi
    ;;
  bs | build-switch)
    shift
    "$0" nixos build "$@" && "$0" nixos switch
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
    echo "$0 $COMMAND build (b): build nixos" >&2
    echo "$0 $COMMAND sdimage: build SD card image (use MACHINE_KEY=user@host to override)" >&2
    echo "$0 $COMMAND boot: add new config to boot, but doesn't switch it until reboot" >&2
    echo "$0 $COMMAND switch (s): switch nixos" >&2
    echo "$0 $COMMAND build-switch (bs): build and switch" >&2
    echo "$0 $COMMAND diff: diff nixos" >&2
    echo "$0 $COMMAND tree: show nixos tree" >&2
    echo "$0 $COMMAND kernel-versions: show kernel versions" >&2
    echo "$0 $COMMAND generations: list generations" >&2
    exit 1
    ;;
  esac
  ;;

c | check)
  shift
  check_home "appaquet@deskapp"
  check_nixos "deskapp"

  check_home "appaquet@utm"
  check_nixos "utm"

  check_nixos "piapp"
  check_home "appaquet@piapp"

  check_nixos "piprint"
  check_home "appaquet@piprint"

  check_nixos "piups"
  check_home "appaquet@piups"

  check_nixos "servapp"
  check_home "appaquet@servapp"

  check_home "appaquet@mbpapp"
  check_eval ".#darwinConfigurations.mbpapp.system"
  ;;

u | update)
  shift
  PACKAGE="$1"
  if [[ -z "$PACKAGE" ]]; then
    echo "Updating all flakes..."
    nix-channel --update
    nix flake update

    read -r -p "Do you want to update all shells? (y/n): " confirm
    if [[ "$confirm" == [yY] ]]; then
      echo "Updating all shells..."
      for shell in shells/*; do
        pushd "${shell}"
        nix flake update
        popd
      done
    else
      echo "Skipping shell updates"
    fi

    echo -e "\n\n!! Don't forget to update explicit package fetches !!"
  else
    nix flake lock --update-input "$PACKAGE"
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

  home-manager expire-generations "-7 days"

  nix-collect-garbage --delete-older-than "7d"

  # Cleaning as root collects more stuff as well
  # See https://www.reddit.com/r/NixOS/comments/10107km/how_to_delete_old_generations_on_nixos/?s=8
  ncg=$(which nix-collect-garbage)
  sudo "${ncg}" -d --delete-older-than "7d"
  ;;

fmt)
  shift
  find . -name "*.nix" -not -path "./humanfirst-dots/*" -exec nixfmt "${@}" {} \;
  ;;

optimize)
  shift
  echo "Optimizing store..."
  nix store optimise
  ;;

b | build)
  shift
  if [[ -z "$HOME_CONFIG" ]]; then
    echo "No home configuration for ${MACHINE_KEY}"
    exit 1
  fi
  if [[ -z "$OS_TYPE" ]]; then
    echo "No OS type for ${MACHINE_KEY}"
    exit 1
  fi

  "$0" home build "$@"
  if [[ "$OS_TYPE" == "nixos" ]]; then
    "$0" nixos build "$@"
  elif [[ "$OS_TYPE" == "darwin" ]]; then
    "$0" darwin build "$@"
  fi
  ;;

s | switch)
  shift
  if [[ -z "$HOME_CONFIG" ]]; then
    echo "No home configuration for ${MACHINE_KEY}"
    exit 1
  fi
  if [[ -z "$OS_TYPE" ]]; then
    echo "No OS type for ${MACHINE_KEY}"
    exit 1
  fi

  "$0" home switch "$@"
  if [[ "$OS_TYPE" == "nixos" ]]; then
    "$0" nixos switch "$@"
  elif [[ "$OS_TYPE" == "darwin" ]]; then
    "$0" darwin switch "$@"
  fi
  ;;

bs | build-switch)
  shift
  "$0" build "$@" && "$0" switch
  ;;

cp | copy)
  shift
  if [[ "$MACHINE_KEY" == "$LOCAL_MACHINE_KEY" ]]; then
    echo "MACHINE_KEY is the same as local machine. Aborting copy."
    exit 1
  fi

  if [[ -z "${DEST_MACHINE_KEY}" ]]; then
    DEST_MACHINE_KEY="${MACHINE_KEY}"
  fi

  echo "Copying ./result to ${DEST_MACHINE_KEY}..."
  nix copy --to "ssh:${DEST_MACHINE_KEY}" ./result

  # Check if result is nixos or home manager by checking for `kernel` in result
  IS_NIXOS=0
  if [[ -f ./result/kernel ]]; then
    IS_NIXOS=1
  fi

  DEST_PATH=$(readlink ./result)
  echo "On the destination machine, run:"
  if [[ $IS_NIXOS -eq 1 ]]; then
    echo "  sudo ${DEST_PATH}/bin/switch-to-configuration switch"
  else
    echo "  ${DEST_PATH}/activate"
  fi
  ;;

*)
  echo "$0 home (h): home manager sub commands" >&2
  echo "$0 darwin (d): darwin sub commands" >&2
  echo "$0 nixos (n): nixos sub commands" >&2
  echo "$0 build (b): build home + system (nixos/darwin)" >&2
  echo "$0 switch (s): switch home + system (nixos/darwin)" >&2
  echo "$0 build-switch (bs): build and switch home + system (nixos/darwin)" >&2
  echo "$0 check (c): eval home & nixos & darwin configs for all hosts" >&2
  echo "$0 update (u): update nix channels" >&2
  echo "$0 link: link system files" >&2
  echo "$0 gc: run garbage collection" >&2
  echo "$0 fmt: format nix files" >&2
  echo "$0 optimize: optimize store" >&2
  echo "$0 copy (cp): copy result to another machine" >&2
  exit 1
  ;;
esac
