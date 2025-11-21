{
  secrets,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/common.nix
    ../modules/common-pi.nix
    ../modules/nasapp.nix
    ../modules/netconsole/receiver.nix
    ./ups-server.nix
  ];

  # /boot is too small, limit to 1 configuration
  boot.loader.raspberryPi.configurationLimit = 1;

  services.openssh.enable = true;

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
    credentials = secrets.piapp.nasappCifs;
    uid = "appaquet";
    gid = "users";

    shares = [
      {
        share = "backup_piapp";
        mount = "/mnt/piapp_backup";
      }
    ];
  };

  services.netconsole.receiver = {
    enable = true;
  };

  system.stateVersion = "24.11";
}
