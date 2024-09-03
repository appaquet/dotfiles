# Adapted from https://astrid.tech/2022/09/22/0/nixos-gpu-vfio/

{ lib, config, ... }:

let
  cfg = config.virtualisation.gpuPassthrough;
in
{
  options.virtualisation.gpuPassthrough = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GPU passthrough";
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Device IDs to pass through. Use `iommulist | grep NVIDIA` to find";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      # Load these kernel modules before everything else
      # load vfio before nouveau drivers so that vfio claims the gpu first
      kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"

        "nouveau"
      ];

      # Enable kernel modules, assign gpu to vfio
      kernelParams = [
        "amd_iommu=on"
        "iommu=pt"
        "kvm.ignore_msrs=1"
        ("vfio-pci.ids=" + lib.concatStringsSep "," cfg.devices)
      ];
    };

    hardware.opengl.enable = true;
  };
}
