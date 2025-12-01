{
  config,
  ...
}:

{
  imports = [
    ../modules/common.nix
    ../modules/common-pi.nix
    ./ups-server.nix
  ];

  networking = {
    hostName = "piups";
    useDHCP = true;
    firewall.enable = false;
  };

  services.openssh.enable = true;

  # OS will reside on sd
  fileSystems = {
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [
        "noatime"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 1 * 1024; # 1GB
    }
  ];

  system.nixos.tags =
    let
      cfg = config.boot.loader.raspberryPi;
    in
    [
      "raspberry-pi-${cfg.variant}"
      cfg.bootloader
      config.boot.kernelPackages.kernel.version
    ];

  system.stateVersion = "25.11";
}
