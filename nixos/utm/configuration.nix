{ ... }:

{
  imports = [
    ../common.nix
    ../cachix.nix
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "utm";

  networking.networkmanager.enable = true;

  networking.firewall.enable = false;
  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
