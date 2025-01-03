{ inputs, ... }:

{
  imports = [
    ../common.nix
    ./hardware-configuration.nix

    inputs.home-manager.nixosModules.home-manager
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "utm";

  networking.networkmanager.enable = true;

  networking.firewall.enable = false;
  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
