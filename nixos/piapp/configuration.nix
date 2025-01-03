{ ...}:

{
  imports = [
    ../common.nix
  ];

  # bcm2711 for rpi 3, 3+, 4, zero 2 w
  # bcm2712 for rpi 5
  # See the docs at:
  # https://www.raspberrypi.com/documentation/computers/linux_kernel.html#native-build-configuration
  raspberry-pi-nix.board = "bcm2712";

  networking.hostName = "piapp";

  services.openssh.enable = true;
  system.stateVersion = "24.11";
}
