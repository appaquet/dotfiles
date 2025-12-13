{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../modules/common.nix
    ../modules/common-pi.nix
  ];

  networking = {
    hostName = "piprint";
    useDHCP = true;
    firewall.enable = false;
  }
  // inputs.secrets.nixos.wifi.home_2_4;

  services.openssh.enable = true;

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      splix
      cups-filters
      cups-browsed
    ];

    startWhenNeeded = false; # don't wait for first connection to start

    listenAddresses = [ "0.0.0.0:631" ];
    allowFrom = [ "all" ];
    browsing = true;
    defaultShared = true;
    openFirewall = true;
    extraConf = ''
      DefaultEncryption Never
    '';

    logLevel = "info";
  };

  hardware.printers.ensurePrinters = [
    {
      name = "Samsung_ML2240";
      deviceUri = "usb://Samsung/ML-2240%20Series";
      model = "samsung/ml2240.ppd";
    }
  ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

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
