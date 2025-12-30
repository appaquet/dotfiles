{
  config,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/common.nix
    ../modules/common-pi.nix
    ../modules/home-manager.nix
    ../modules/nasapp.nix
    ../modules/netconsole/receiver.nix
  ];

  home-manager.users.appaquet = import ../../home-manager/piapp.nix;

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

  sops.secrets.nasapp_cifs.sopsFile = config.sops.secretsFiles.home;

  nasapp = {
    enable = true;
    credentials = config.sops.secrets.nasapp_cifs.path;
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
