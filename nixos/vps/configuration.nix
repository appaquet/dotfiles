{
  config,
  ...
}:
{
  imports = [
    ../modules/common.nix
    ../modules/restic/server.nix
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
    ports = [ 22222 ];
    settings.PasswordAuthentication = false;
  };
  networking.firewall.allowedTCPPorts = [ 22222 ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "datapool" ];

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    trim = {
      enable = true;
      interval = "weekly";
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
  };

  restic-server = {
    enable = true;
    dataDir = "/data/restic";
    sopsFile = config.sops.secretsFiles.vps;
  };

  sops.secrets.mqtt.sopsFile = config.sops.secretsFiles.dotblip;
  dotblip = {
    enable = true;
    user = "appaquet";
    mqtt = {
      host = "haos.n3x.net";
      port = 1883;
      credentialsFile = config.sops.secrets.mqtt.path;
    };
    reporters = {
      system = {
        enable = true;
        interval = 3600;
      };
      restic = {
        enable = true;
        directoryBackups = [
          { root = "/data/restic/nasapp"; }
        ];
        interval = 3600;
      };
    };
  };

  system.stateVersion = "25.11";
}
