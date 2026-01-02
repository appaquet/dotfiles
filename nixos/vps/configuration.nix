{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../modules/common.nix
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "vps";
  networking.hostId = "2f1f15c1"; # used for zfs, preventing accidental pool import conflicts

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

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  nix = {
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];
    };
  };

  system.stateVersion = "25.11";
}
