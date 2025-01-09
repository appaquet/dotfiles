{ secrets, ... }:

{
  imports = [
    ../common.nix
    ../nasapp.nix
  ];

  # From https://github.com/NixOS/nixpkgs/issues/260754
  # and https://github.com/nix-community/raspberry-pi-nix
  #
  # See the docs at:
  #   bcm2711 for rpi 3, 3+, 4, zero 2 w
  #   bcm2712 for rpi 5
  #   https://www.raspberrypi.com/documentation/computers/linux_kernel.html#native-build-configuration
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

  nasapp = {
    enable = true;
    credentials = secrets.deskapp.nasappCifs;
    uid = "appaquet";
    gid = "users";

    shares = [
      {
        share = "backup_piapp";
        mount = "/mnt/piapp_backup";
      }
    ];
  };

  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
