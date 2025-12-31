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

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22222 ];

  services.openssh = {
    enable = true;
    ports = [ 22222 ];
    settings.PasswordAuthentication = false;
  };

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
