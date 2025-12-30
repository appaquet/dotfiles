{ ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/home-manager.nix
    ./hardware-configuration.nix
  ];

  home-manager.users.appaquet = import ../../home-manager/utm.nix;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "utm";

  networking.networkmanager.enable = true;

  networking.firewall.enable = false;
  services.openssh.enable = true;

  system.stateVersion = "25.01";
}
