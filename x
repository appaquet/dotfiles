#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$ROOT" >/dev/null

LOCAL_HOSTNAME=$(uname -n | tr '[:upper:]' '[:lower:]' | sed 's/\.local//')
HOST="${HOST:-$LOCAL_HOSTNAME}"

NIX_BUILDER="nix"
if [[ -x ~/.nix-profile/bin/nom ]]; then
  NIX_BUILDER="nom"
fi

# Host configuration functions
host_config_deskapp() {
  HOME_CONFIG="appaquet@deskapp"
  OS_TYPE="nixos"
}

host_config_servapp() {
  HOME_CONFIG="appaquet@servapp"
  OS_TYPE="nixos"
}

host_config_utm() {
  HOME_CONFIG="appaquet@utm"
  OS_TYPE="nixos"
}

host_config_piapp() {
  HOME_CONFIG="appaquet@piapp"
  OS_TYPE="nixos"
}

host_config_piprint() {
  HOME_CONFIG="appaquet@piprint"
  OS_TYPE="nixos"
}

host_config_piups() {
  HOME_CONFIG="appaquet@piups"
  OS_TYPE="nixos"
}

host_config_vps() {
  HOME_CONFIG="appaquet@vps"
  OS_TYPE="nixos"
}

host_config_mbpapp() {
  HOME_CONFIG="appaquet@mbpapp"
  OS_TYPE="darwin"
}

ALL_HOSTS=(deskapp servapp utm piapp piprint piups vps mbpapp)

# Core helper functions
resolve_host() {
  local host="$1"

  HOME_CONFIG=""
  OS_TYPE=""

  if declare -f "host_config_${host}" >/dev/null; then
    "host_config_${host}"
    : "${SSH_HOST:=${host}.n3x.net}"
  else
    echo "Unknown host: ${host}" >&2
    exit 1
  fi
}

is_remote() {
  [[ "$LOCAL_HOSTNAME" != "$HOST" ]]
}

require_local() {
  if is_remote; then
    echo "This command must run on the target machine" >&2
    exit 1
  fi
}

prime_sudo() {
  sudo echo >/dev/null
}

check_eval() {
  nix eval --raw "${1}"
}

# Remote operation functions
remote_copy() {
  local result_path
  result_path=$(readlink -f ./result)

  echo "Copying ${result_path} to ${SSH_HOST}..." >&2
  nix copy --to "ssh://${SSH_HOST}" ./result

  echo "$result_path"
}

remote_nixos_switch() {
  local result_path
  result_path=$(remote_copy)

  echo "Switching on ${SSH_HOST}..."
  ssh -t "${SSH_HOST}" "sudo nix-env --profile /nix/var/nix/profiles/system --set ${result_path} && sudo ${result_path}/bin/switch-to-configuration switch"
}

remote_nixos_boot() {
  local result_path
  result_path=$(remote_copy)

  echo "Adding to boot on ${SSH_HOST}..."
  ssh -t "${SSH_HOST}" "sudo nix-env --profile /nix/var/nix/profiles/system --set ${result_path} && sudo ${result_path}/bin/switch-to-configuration boot"
}

remote_home_switch() {
  local result_path
  result_path=$(remote_copy)

  echo "Activating home-manager on ${SSH_HOST}..."
  ssh -t "${SSH_HOST}" "${result_path}/activate"
}

# Home command handlers
cmd_home_check() {
  echo "Checking home ${HOME_CONFIG}"
  check_eval ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
}

cmd_home_build() {
  ${NIX_BUILDER} build "$@" ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
}

cmd_home_switch() {
  local generation="${1:-}"

  if is_remote; then
    remote_home_switch
    return
  fi

  if [[ -n "$generation" ]]; then
    local gen_path
    gen_path=$(home-manager generations | grep "id ${generation}" | awk '{print $7}')
    if [[ -z "$gen_path" ]]; then
      echo "Generation $generation not found"
      exit 1
    fi
    echo "Activating generation $generation at $gen_path"
    "$gen_path"/activate
  else
    echo "Activating latest generation"
    ./result/activate
  fi
}

cmd_home_diff() {
  nvd diff ~/.local/state/nix/profiles/home-manager ./result
}

cmd_home_tree() {
  nix-tree ~/.local/state/nix/profiles/home-manager
}

cmd_home_generations() {
  home-manager generations
}

cmd_home_diff_generations() {
  nix profile diff-closures --profile ~/.local/state/nix/profiles/home-manager
}

cmd_home_help() {
  cat >&2 <<EOF
usage: $0 home <command> [args]

  check             Eval home config
  build (b)         Build home config
  switch (s)        Activate home config (or generation N)
  build-switch (bs) Build and switch
  diff              Diff ./result with current
  tree              Show dependency tree
  generations       List generations
  diff-generations  Diff between generations
EOF
  exit 1
}

# Darwin command handlers
cmd_darwin_check() {
  echo "Checking darwin ${HOST}"
  check_eval ".#darwinConfigurations.${HOST}.system"
}

cmd_darwin_build() {
  ${NIX_BUILDER} build "$@" ".#darwinConfigurations.${HOST}.system"
}

cmd_darwin_switch() {
  require_local
  sudo ./result/sw/bin/darwin-rebuild switch --flake .
}

cmd_darwin_diff() {
  nvd diff /run/current-system result
}

cmd_darwin_tree() {
  nix-tree ~/.nix-profile
}

cmd_darwin_help() {
  cat >&2 <<EOF
usage: $0 darwin <command> [args]

  check             Eval darwin config
  build (b)         Build darwin config
  switch (s)        Switch darwin config
  build-switch (bs) Build and switch
  diff              Diff ./result with current
  tree              Show dependency tree
EOF
  exit 1
}

# NixOS command handlers
cmd_nixos_check() {
  echo "Checking nixos ${HOST}"
  check_eval ".#nixosConfigurations.${HOST}.config.system.build.toplevel"
}

cmd_nixos_build() {
  ${NIX_BUILDER} build "$@" ".#nixosConfigurations.${HOST}.config.system.build.toplevel"
}

cmd_nixos_sdimage() {
  echo "Building SD card image for ${HOST}..."
  ${NIX_BUILDER} build ".#nixosConfigurations.${HOST}.config.system.build.sdImage"

  if [[ -L ./result ]]; then
    local image
    image=$(find ./result -name "*.img.zst" -o -name "*.img" | head -1)
    if [[ -n "$image" ]]; then
      echo ""
      echo "SD image built successfully!"
      echo "Image: $image"
      echo ""
      echo "To write to SD card:"
      if [[ "$image" == *.zst ]]; then
        echo "  zstdcat $image | sudo dd of=/dev/sdX bs=4M status=progress"
      else
        echo "  sudo dd if=$image of=/dev/sdX bs=4M status=progress"
      fi
    fi
  fi
}

cmd_nixos_boot() {
  if is_remote; then
    remote_nixos_boot
    return
  fi

  prime_sudo
  sudo nixos-rebuild boot --flake ".#${HOST}"
}

cmd_nixos_switch() {
  local generation="${1:-}"

  if is_remote; then
    remote_nixos_switch
    return
  fi

  read -r -p "Are you sure you want to switch now. Switching on next boot is recommended (y/n): " confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "Aborting switch"
    exit 1
  fi
  echo "Switching now..."

  prime_sudo
  if [[ -n "$generation" ]]; then
    local gen_path="/nix/var/nix/profiles/system-${generation}-link"
    if [[ ! -d "$gen_path" ]]; then
      echo "Generation $generation not found"
      exit 1
    fi
    echo "Activating generation $generation at $gen_path"
    sudo "$gen_path"/activate
  else
    echo "Activating latest generation"
    sudo nixos-rebuild switch --flake ".#${HOST}"
  fi
}

cmd_nixos_diff() {
  nvd diff /run/current-system result
}

cmd_nixos_tree() {
  nix-tree /run/current-system
}

cmd_nixos_kernel_versions() {
  local booted current result has_diff=0

  booted=$(readlink /run/booted-system/{initrd,kernel,kernel-modules} | tr '\n' ' ')
  current=$(readlink /run/current-system/{initrd,kernel,kernel-modules} | tr '\n' ' ')
  result=$(readlink ./result/{initrd,kernel,kernel-modules} | tr '\n' ' ')

  if [[ "$booted" != "$current" ]]; then
    has_diff=1
    echo "Booted kernel isn't the same as last generation"
    echo "  Booted: $booted"
    echo "  Current: $current"
    echo " "
  fi

  if [[ "$booted" != "$result" ]]; then
    has_diff=1
    echo "Booted kernel isn't the same as the one in ./result"
    echo "  Booted: $booted"
    echo "  Result: $result"
  fi

  if [[ "$has_diff" -eq 0 ]]; then
    echo "Kernel versions are consistent"
  fi
}

cmd_nixos_generations() {
  nix profile history --profile /nix/var/nix/profiles/system
}

cmd_nixos_help() {
  cat >&2 <<EOF
usage: $0 nixos <command> [args]

  check             Eval nixos config
  build (b)         Build nixos config
  boot              Add to boot (activate on reboot)
  switch (s)        Switch nixos config now
  build-switch (bs) Build and switch
  sdimage           Build SD card image
  diff              Diff ./result with current
  tree              Show dependency tree
  kernel-versions   Show kernel version info
  generations       List generations
EOF
  exit 1
}

# Top-level command handlers
cmd_check_all() {
  for host in "${ALL_HOSTS[@]}"; do
    resolve_host "$host"
    [[ -n "$HOME_CONFIG" ]] && {
      echo "Checking home ${HOME_CONFIG}"
      check_eval ".#homeConfigurations.${HOME_CONFIG}.activationPackage"
    }
    case "$OS_TYPE" in
    nixos)
      echo "Checking nixos ${host}"
      check_eval ".#nixosConfigurations.${host}.config.system.build.toplevel"
      ;;
    darwin)
      echo "Checking darwin ${host}"
      check_eval ".#darwinConfigurations.${host}.system"
      ;;
    esac
  done
}

cmd_update() {
  local package="$1"
  if [[ -z "$package" ]]; then
    echo "Updating all flakes..."
    nix-channel --update
    nix flake update

    read -r -p "Do you want to update all shells? (y/n): " confirm
    if [[ "$confirm" == [yY] ]]; then
      echo "Updating all shells..."
      for shell in shells/*; do
        pushd "${shell}" >/dev/null
        nix flake update
        popd >/dev/null
      done
    else
      echo "Skipping shell updates"
    fi

    echo -e "\n\n!! Don't forget to update explicit package fetches !!"
  else
    nix flake lock --update-input "$package"
  fi
}

cmd_gc() {
  if is_remote; then
    echo "Garbage collecting on ${SSH_HOST}..."
    ssh -t "${SSH_HOST}" "home-manager expire-generations \"-14 days\""
    ssh -t "${SSH_HOST}" "nix-collect-garbage --delete-older-than 14d"
    ssh -t "${SSH_HOST}" "sudo nix-collect-garbage --delete-older-than 14d"
    return
  fi

  echo "Garbage collecting..."

  home-manager expire-generations "-7 days"
  nix-collect-garbage --delete-older-than "7d"

  local ncg
  ncg=$(which nix-collect-garbage)
  sudo "${ncg}" --delete-older-than "7d"
}

cmd_fmt() {
  find . -name "*.nix" -not -path "./humanfirst-dots/*" -exec nixfmt "$@" {} \;
}

cmd_optimize() {
  echo "Optimizing store..."
  nix store optimise
}

cmd_build_all() {
  if [[ -z "$HOME_CONFIG" ]]; then
    echo "No home configuration for HOST=${HOST}"
    exit 1
  fi
  if [[ -z "$OS_TYPE" ]]; then
    echo "No OS type for HOST=${HOST}"
    exit 1
  fi

  "$0" home build "$@"
  case "$OS_TYPE" in
  nixos) "$0" nixos build "$@" ;;
  darwin) "$0" darwin build "$@" ;;
  esac
}

cmd_build_switch_all() {
  if [[ -z "$HOME_CONFIG" ]]; then
    echo "No home configuration for HOST=${HOST}"
    exit 1
  fi
  if [[ -z "$OS_TYPE" ]]; then
    echo "No OS type for HOST=${HOST}"
    exit 1
  fi

  "$0" home build "$@" && "$0" home switch
  case "$OS_TYPE" in
  nixos) "$0" nixos build "$@" && "$0" nixos switch ;;
  darwin) "$0" darwin build "$@" && "$0" darwin switch ;;
  esac
}

cmd_copy() {
  if ! is_remote; then
    echo "HOST is the same as local machine. Aborting copy."
    exit 1
  fi

  local result_path
  result_path=$(remote_copy)

  local is_nixos=0
  [[ -f ./result/kernel ]] && is_nixos=1

  echo "On the destination machine, run:"
  if [[ $is_nixos -eq 1 ]]; then
    echo "  sudo ${result_path}/bin/switch-to-configuration switch"
  else
    echo "  ${result_path}/activate"
  fi
}

cmd_help() {
  cat >&2 <<EOF
usage: $0 <command> [args]

System Targets:
  home (h)     check|build|switch|diff|tree|generations
  darwin (d)   check|build|switch|diff|tree
  nixos (n)    check|build|switch|boot|diff|tree|sdimage

Unified:
  build (b)         Build home + system for current host
  build-switch (bs) Build and switch all
  check (c)         Eval all configs for all hosts
  copy (cp)         Copy result to remote host

Utilities:
  fmt          Format nix files
  update (u)   Update flake inputs
  gc           Garbage collect
  optimize     Optimize nix store

Environment: HOST=<name> to target remote machine
EOF
  exit 1
}

# Resolve host and main dispatch
resolve_host "$HOST"

COMMAND=$1
case $COMMAND in
h | home)
  shift
  case $1 in
  check)
    shift
    cmd_home_check "$@"
    ;;
  b | build)
    shift
    cmd_home_build "$@"
    ;;
  s | switch)
    shift
    cmd_home_switch "$@"
    ;;
  bs | build-switch)
    shift
    cmd_home_build "$@" && cmd_home_switch
    ;;
  diff)
    shift
    cmd_home_diff
    ;;
  tree)
    shift
    cmd_home_tree
    ;;
  generations)
    shift
    cmd_home_generations
    ;;
  diff-generations)
    shift
    cmd_home_diff_generations
    ;;
  *) cmd_home_help ;;
  esac
  ;;

d | darwin)
  shift
  case $1 in
  check)
    shift
    cmd_darwin_check "$@"
    ;;
  b | build)
    shift
    cmd_darwin_build "$@"
    ;;
  s | switch)
    shift
    cmd_darwin_switch "$@"
    ;;
  bs | build-switch)
    shift
    cmd_darwin_build "$@" && cmd_darwin_switch
    ;;
  diff)
    shift
    cmd_darwin_diff
    ;;
  tree)
    shift
    cmd_darwin_tree
    ;;
  *) cmd_darwin_help ;;
  esac
  ;;

n | nixos)
  shift
  case $1 in
  check)
    shift
    cmd_nixos_check "$@"
    ;;
  b | build)
    shift
    cmd_nixos_build "$@"
    ;;
  s | switch)
    shift
    cmd_nixos_switch "$@"
    ;;
  boot)
    shift
    cmd_nixos_boot "$@"
    ;;
  bs | build-switch)
    shift
    cmd_nixos_build "$@" && cmd_nixos_switch
    ;;
  bb | build-boot)
    shift
    cmd_nixos_build "$@" && cmd_nixos_boot
    ;;
  sdimage)
    shift
    cmd_nixos_sdimage "$@"
    ;;
  diff)
    shift
    cmd_nixos_diff
    ;;
  tree)
    shift
    cmd_nixos_tree
    ;;
  kernel-versions)
    shift
    cmd_nixos_kernel_versions
    ;;
  generations)
    shift
    cmd_nixos_generations
    ;;
  *) cmd_nixos_help ;;
  esac
  ;;

c | check)
  shift
  cmd_check_all "$@"
  ;;
u | update)
  shift
  cmd_update "$@"
  ;;
gc)
  shift
  cmd_gc "$@"
  ;;
fmt)
  shift
  cmd_fmt "$@"
  ;;
optimize)
  shift
  cmd_optimize "$@"
  ;;
b | build)
  shift
  cmd_build_all "$@"
  ;;
bs | build-switch)
  shift
  cmd_build_switch_all "$@"
  ;;
cp | copy)
  shift
  cmd_copy "$@"
  ;;
*) cmd_help ;;
esac
