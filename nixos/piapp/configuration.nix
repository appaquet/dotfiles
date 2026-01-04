{
  config,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/common.nix
    ../modules/common-pi.nix
    ../modules/nasapp.nix
    ../modules/netconsole/receiver.nix
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

  sops.secrets.nasapp_cifs.sopsFile = config.sops.secretsFiles.home;

  services.netconsole.receiver = {
    enable = true;
  };

  system.stateVersion = "24.11";
}
