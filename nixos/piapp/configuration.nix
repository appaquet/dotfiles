{ secrets, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../nasapp.nix
    ../netconsole/receiver.nix
    ./ups-server.nix
  ];

  # Limit boot generations to 1 due to small 128MB boot partition
  boot.loader.raspberryPi.configurationLimit = 1;

  # Only include firmware needed for RPi5 (save ~700MB)
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = with pkgs; [
    wireless-regdb
    raspberrypi-wireless-firmware  # BCM WiFi/BT firmware
  ];

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

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    libraspberrypi # Provides vcgencmd, GPU tools
    raspberrypi-eeprom # Provides rpi-eeprom-update, rpi-eeprom-config
  ];

  system.stateVersion = "24.11";
}
