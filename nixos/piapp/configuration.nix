{ ... }:

{
  # From https://github.com/NixOS/nixpkgs/issues/260754
  # and https://github.com/nix-community/raspberry-pi-nix

  imports = [
    ../common.nix
  ];

  # bcm2711 for rpi 3, 3+, 4, zero 2 w
  # bcm2712 for rpi 5
  # See the docs at:
  # https://www.raspberrypi.com/documentation/computers/linux_kernel.html#native-build-configuration
  raspberry-pi-nix = {
    uboot.enable = false;
    board = "bcm2712";
  };

  networking = {
    hostName = "piapp";
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = false;
      eth0.useDHCP = true;
    };
    firewall.enable = false;
  };

  services.openssh.enable = true;
  system.stateVersion = "24.11";
}
