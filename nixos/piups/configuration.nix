{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../common.nix
    ../common-pi.nix
  ];

  networking = {
    hostName = "piups";
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = false;
      eth0.useDHCP = true;
    };
    firewall.enable = false;
  };

  services.openssh.enable = true;

  # CUPS printing service for Samsung ML-2240
  services.printing = {
    enable = true;
    drivers = [ pkgs.splix ];

    # Network sharing configuration
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    browsing = true;
    defaultShared = true;
    openFirewall = true;

    # Disable SSL to avoid certificate errors in web interface
    extraConf = ''
      DefaultEncryption Never
    '';

    logLevel = "info";
  };

  # Avahi for printer discovery on Linux/macOS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Add user to printer admin group
  users.users.appaquet.extraGroups = [ "lp" ];

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
