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
      description = "PCI identifiers to passthrough";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      # Load these kernel modules before everything else
      # so that nvidia drivers don't claim the gpu
      kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
      ];

      # Enable kernel modules, assign gpu to vfio
      kernelParams = [
        "amd_iommu=on"
        "iommu=pt"
        "kvm.ignore_msrs=1"
        ("vfio-pci.ids=" + lib.concatStringsSep "," cfg.devices)
      ];
    };

    hardware.graphics.enable = true;
  };
}
