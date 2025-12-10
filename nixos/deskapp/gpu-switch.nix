{ pkgs, config, ... }:

let
  # Keep in sync with ./virt/default.nix
  gpuPci = "10de:2216";
  audioPci = "10de:1aef";

  # GPU switching script
  # Used in qemu hooks defined in `./virt/default.nix`
  gpuSwitch = pkgs.writeShellScriptBin "gpu-switch" ''
    #!/usr/bin/env bash
    set -uo pipefail

    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi

    export PATH="$PATH:/run/current-system/sw/bin/"

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
            echo $audio_bus >/sys/bus/pci/drivers/$gpu_driver/unbind || true
            sleep 5
        fi

        # Force removal, otherwise drivers may not recognize the device (especially if it comes back from windows)
        echo "Removing GPU and audio devices"
        echo "1" > /sys/bus/pci/devices/$gpu_bus/remove || true
        echo "1" > /sys/bus/pci/devices/$audio_bus/remove || true
        sleep 5

        if [ "$to_driver" == "nvidia" ]; then
            echo "Loading nvidia drivers..."
            modprobe -r vfio_pci vfio vfio_iommu_type1
            modprobe -a nvidia nvidia_modeset nvidia_uvm nvidia_drm
            sleep 5
        elif [ "$to_driver" == "vfio-pci" ]; then
            echo "Loading vfio drivers..."
            rmmod nvidia_drm # modprobe -r doesn't seem to always work... order is important
            rmmod nvidia_uvm
            rmmod nvidia_modeset
            rmmod nvidia
            modprobe -a vfio_pci vfio vfio_iommu_type1
            sleep 5
        fi

        gpu_driver=$(get_bus_driver $gpu_bus)
        if [ "$gpu_driver" == "$to_driver" ]; then
            echo "Loading drivers bound to $to_driver automatically"
            exit 0
        fi

        echo "Rescanning PCI bus"
        echo "1" > /sys/bus/pci/rescan

        sleep 5

        echo "Binding GPU to $to_driver"
        echo $gpu_bus >/sys/bus/pci/drivers/$to_driver/bind || true
        echo $audio_bus >/sys/bus/pci/drivers/$to_driver/bind || true

        sleep 5
    }

    function nvidia() {
        echo "Switching to nvidia driver..."

        # Remove vfio blacklist to allow nvidia modules to load
        rm -f /run/modprobe.d/nvidia-vfio-blacklist.conf

        switch_driver "nvidia"

        # Force drivers to persist, preventing high power usage on idle
        nvidia-smi -pm 1

        # Restart nvidia docker related stuff to make sure they get rebound
        systemctl reset-failed docker.service
        systemctl restart docker.service
    }

    function vfio() {
        echo "Switching to vfio-pci driver..."

        if pgrep -x "process-compose" > /dev/null; then
            echo "Stopping process compose..."
            pkill process-compose || true
            sleep 10 # Give it time to stop
            pkill -9 process-compose || true
        fi

        # Blacklist nvidia modules to prevent udev/cdi-generator from loading them
        mkdir -p /run/modprobe.d
        echo "blacklist nvidia" > /run/modprobe.d/nvidia-vfio-blacklist.conf
        echo "blacklist nvidia_drm" >> /run/modprobe.d/nvidia-vfio-blacklist.conf
        echo "blacklist nvidia_modeset" >> /run/modprobe.d/nvidia-vfio-blacklist.conf
        echo "blacklist nvidia_uvm" >> /run/modprobe.d/nvidia-vfio-blacklist.conf

        # Nvidia containers will keep trying to use the nvidia driver if it's loaded
        # Leading to spammy errors in the logs. We don't need it while we're gaming anyway.
        systemctl stop nvidia-container-toolkit-cdi-generator.service
        systemctl stop docker.service

        switch_driver "vfio-pci"
    }

    function status() {
        gpu_bus=$(format_bus $(get_bus "${gpuPci}"))
        gpu_driver=$(get_bus_driver $gpu_bus)
        echo "$gpu_driver"
    }

    CMD="''${1:-status}"
    shift
    $CMD "$@"
  '';
in
{
  # Enable both nvidia & amd drivers, even if nvidia won't be used for display. This allow
  # installing drivers.
  services.xserver.videoDrivers = [
    "nvidia"
    "amdgpu"
  ];

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

  systemd.services.switch-gpu-boot = {
    description = "Switch GPU to NVIDIA on boot";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${gpuSwitch}/bin/gpu-switch nvidia";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.switch-gpu-boot-after-resume = {
    description = "Switch GPU to NVIDIA on resume (rebinding it to make sure it works)";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "switch-gpu-after-resume" ''
        ${gpuSwitch}/bin/gpu-switch vfio
        ${gpuSwitch}/bin/gpu-switch nvidia
      ''}";
    };
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
  };

}
