# From https://astrid.tech/2022/09/22/0/nixos-gpu-vfio/

let
  # iommulist | grep NVIDIA
  gpuIDs = [
    "10de:2216" # Graphics
    "10de:1aef" # Audio
  ];
in
{ lib, ... }: {
  boot = {
    # Load these kernel modules before everything else
    # load vfio before nouveau drivers so that vfio claims the gpu first
    initrd.kernelModules = [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"

      "nouveau"
    ];

    # enable kernel modules, assign gpu to vfio
    kernelParams = [
      "amd_iommu=on"
      "kvm.ignore_msrs=1"
      "iommu=pt"
      ("vfio-pci.ids=" + lib.concatStringsSep "," gpuIDs)
    ];
  };

  hardware.opengl.enable = true;
}
