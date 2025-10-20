{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Note: lib.mkDefault is used here because this hardware-configuration.nix is shared
  # by both the regular piapp config (uses NVMe UUIDs below) and piapp-sdimage config
  # (needs to override with /dev/disk/by-label/NIXOS_SD for SD card images).
  # Without mkDefault, the two configurations would conflict.
  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = lib.mkDefault "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = lib.mkDefault "/dev/disk/by-uuid/2178-694E";
    fsType = lib.mkDefault "vfat";
    options = lib.mkDefault [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
