{
  config,
  ...
}:

{
  imports = [
    ../modules/common.nix
    ../modules/common-pi.nix
    ../modules/netconsole/receiver.nix
  ];

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

  services.netconsole.receiver = {
    enable = true;
  };

  system.nixos.tags =
    let
      cfg = config.boot.loader.raspberryPi;
    in
    [
      "raspberry-pi-${cfg.variant}"
      cfg.bootloader
      config.boot.kernelPackages.kernel.version
    ];

  system.stateVersion = "25.11";
}
