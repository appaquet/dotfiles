{ pkgs, config, ... }:

# TODO: systemd on boot to switch ?
# TODO: qemu hooks

let
  # Keep in sync with ./virt/default.nix
  gpuPci = "10de:2216";
  audioPci = "10de:1aef";

  gpuSwitch = pkgs.writeShellScriptBin "gpu-switch" ''
    #!/usr/bin/env bash
    set -uo pipefail

    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi

    function get_bus() {
        # takes a PCI device identifier (ex: 10de:2216) and returns the bus address (ex: 01:00.0)
        lspci -nn | grep "$1" | awk '{print $1}'
    }

    function format_bus() {
        # format bus address 01:00.0 to 0000:01:00.0
        echo "0000:$1"
    }

    function get_bus_driver() {
        # takes a bus address (ex: 0000:01:00.0) and returns the driver in use (ex: nvidia, vfio-pci)
        echo $(lspci -nn -s $1 -k | grep "Kernel driver in use" | awk '{print $5}')
    }

    function switch_driver() {
        to_driver=$1

        echo "Switching to $to_driver..."

        gpu_bus=$(format_bus $(get_bus "${gpuPci}"))
        audio_bus=$(format_bus $(get_bus "${audioPci}"))

        gpu_driver=$(get_bus_driver $gpu_bus)
        if [ "$gpu_driver" == "$to_driver" ]; then
            echo "GPU already using $to_driver driver"
            exit 0
        fi

        if [ "$gpu_driver" != "" ]; then
            echo "Unbinding GPU from $gpu_driver"
            echo $gpu_bus >/sys/bus/pci/drivers/$gpu_driver/unbind
            echo $audio_bus >/sys/bus/pci/drivers/$gpu_driver/unbind
            sleep 5
        fi

        if [ "$to_driver" == "nvidia" ]; then
            echo "Loading nvidia drivers..."
            modprobe -a nvidia nvidia_modeset nvidia_uvm nvidia_drm
            sleep 5
        elif [ "$to_driver" == "vfio-pci" ]; then
            echo "Loading vfio drivers..."
            modprobe -a vfio_pci vfio vfio_iommu_type1
            sleep 5
        fi

        gpu_driver=$(get_bus_driver $gpu_bus)
        if [ "$gpu_driver" == "$to_driver" ]; then
            echo "Loading drivers bound to $to_driver automatically"
            exit 0
        fi

        sleep 2
        echo "Binding GPU to $to_driver"
        echo $gpu_bus >/sys/bus/pci/drivers/$to_driver/bind
        echo $audio_bus >/sys/bus/pci/drivers/$to_driver/bind
    }

    function nvidia() {
        switch_driver "nvidia"
    }

    function vfio() {
        switch_driver "vfio-pci"
    }

    CMD="$1"
    shift
    $CMD "$@"
  '';
in
{
  # Enable both nvidia & amd drivers, even if nvidia won't be used for display. This allow
  # installing drivers.
  services.xserver.videoDrivers = [ "nvidia" "amdgpu" ];

  # From https://nixos.wiki/wiki/Nvidia
  hardware.nvidia = {
    # Hinders with dynamic switching since it manages the card using KMS
    # https://forums.developer.nvidia.com/t/unbinding-isolating-a-card-is-difficult-post-470/223134
    modesetting.enable = false;

    powerManagement.enable = false;
    powerManagement.finegrained = false;

    open = false;

    nvidiaSettings = false; # no need for settings menu

    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # To test: docker run --rm -it --device=nvidia.com/gpu=all ubuntu:latest nvidia-smi
  hardware.nvidia-container-toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    gpuSwitch
  ];
}
