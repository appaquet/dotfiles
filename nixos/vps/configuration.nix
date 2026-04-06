{
  config,
  ...
}:
{
  imports = [
    ../modules/common.nix
    ../modules/dotblip.nix
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "vps";
  networking.hostId = "2f1f15c1"; # used for zfs, preventing accidental pool import conflicts

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  networking.firewall.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;
    ports = [ 22222 ];
    settings.PasswordAuthentication = false;
  };

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "datapool" ];

  services.zfs = {
    autoScrub = {
      enable = true;
    };
    trim = {
      enable = true;
    };
  };

  dotblip = {
    reporters.zfs = {
      enable = true;
      pools = [ "datapool" ];
    };
  };

  services.sanoid = {
    enable = true;
    datasets."datapool" = {
      autosnap = true;
      autoprune = true;
      daily = 30;
      hourly = 0;
      monthly = 3;
      yearly = 0;
      recursive = true;
    };

    # zfs sent snapshots from servapp
    datasets."datapool/backup-servapp" = {
      autosnap = false;
      autoprune = true;
      daily = 30;
      monthly = 3;
      yearly = 0;
      hourly = 0;
      recursive = true;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAnTd9pnNTuLtfjQyQ1mRNEjH5e7zoMceHlAx19I9Zu syncoid@servapp"
  ];

  system.stateVersion = "25.11";
}
