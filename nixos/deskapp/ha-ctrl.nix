{ pkgs, config, ... }:

let
  haCtrl = pkgs.writeShellScriptBin "ha-ctrl" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ $EUID -ne 0 ]]; then
      echo "This script must be run as root" 1>&2
      exit 1
    fi

    function vm_running() {
      virsh list --state-running --name | grep -q $1
    }

    function vm_stop() {
      VM=$1
        
      if ! vm_running "$VM"; then
        echo "$VM not running"
        return
      fi

      virsh shutdown $VM

      for i in `seq 0 40`; do # needs to be <60s since HA timeouts after 1m
        sleep 1
        if ! vm_running "$VM"; then
          return
        else 
          echo "$VM is still running..."
        fi
      done

      echo "Waited for too long, destroying it..."
      virsh destroy $VM
    }

    function vm_stop_all() {
      for vm in $(virsh list --all --name); do
        vm_stop $vm
      done
    }

    function vm_start() {
      VM=$1

      if vm_running "$VM"; then
        echo "$VM already running"
        return
      fi

      virsh start $VM
    }

    function vm() {
      CMD="$1"
      shift

      case "$CMD" in
        start)
          VM="$1"
          if [[ "$VM" == "win10" ]]; then
            vm_stop embed
            vm_start win10
          elif [[ "$VM" == "embed" ]]; then
            vm_stop win10
            vm_start embed
          else
            echo "Unknown VM: $VM"
            exit 1
          fi
          ;;

        stop)
          VM="$1"
          vm_stop $VM
          ;;

        *)
          echo "Unknown command: $CMD"
          exit 1
          ;;
      esac
    }

    function suspend() {
      vm_stop_all
      systemctl suspend
    }

    function shutdown() {
      vm_stop_all
      systemctl poweroff
    }

    function reboot() {
      vm_stop_all
      reboot
    }

    function gpu_status() {
      /run/current-system/sw/bin/gpu-switch status
    }

    function gpu_vfio() {
      /run/current-system/sw/bin/gpu-switch vfio
    }

    function gpu_nvidia() {
      /run/current-system/sw/bin/gpu-switch nvidia
    }

    CMD="$1"
    shift
    $CMD "$@"
  '';

in
{
  environment.systemPackages = [ haCtrl ];

  security.sudo = {
    extraRules = [
      {
        commands = [
          {
            command = "${config.system.path}/bin/ha-ctrl"; # sudoers file wants explicit path
            options = [ "NOPASSWD" ];
          }
        ];
        groups = [ "wheel" ];
      }
    ];
  };
}
