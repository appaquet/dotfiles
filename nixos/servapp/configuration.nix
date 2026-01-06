{
  config,
  ...
}:

{
  imports = [
    ../modules/common.nix
    ../modules/dev.nix
    ../modules/docker.nix
    ../modules/nasapp.nix
    ../modules/network-bridge.nix
    ../modules/ups/client.nix
    ../modules/netconsole/sender.nix
    ../modules/restic/backup.nix
    ./hardware-configuration.nix
    ./virt
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    "kernel.panic" = 60; # Restart delay after panic
  };

  networking.hostName = "servapp";

  # Drives
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  # Networking
  networking.myBridge = {
    enable = true;
    interface = "enp1s0";
    lanIp = "192.168.0.13";
  };
  networking.firewall.enable = false;

  services.netconsole.sender = {
    enable = true;
    interface = "br0";
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  sops.secrets.nasapp_cifs.sopsFile = config.sops.secretsFiles.home;

  # NasAPP mounts
  nasapp = {
    enable = true;
    credentials = config.sops.secrets.nasapp_cifs.path;
    uid = "appaquet";
    gid = "users";
    shares = [
      {
        share = "video";
        mount = "/mnt/video";
      }
    ];
  };

  restic-backup = {
    enable = true;
    sopsFile = config.sops.secretsFiles.home;

    backups.home = {
      paths = [ "/home/appaquet" ];
      exclude = [
        "homeassistant"
        "pihole"
      ];
    };

    backups.vms = {
      paths = [
        "/home/appaquet/homeassistant"
        "/home/appaquet/pihole"
      ];
      schedule = "weekly";
      pruneOpts = [
        "--keep-weekly 4"
      ];
    };
  };

  # Display
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "appaquet";

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Programs & services
  programs.firefox.enable = true;
  services.printing.enable = false;
  services.openssh.enable = true;

  # UPS
  power.myUps = {
    enable = true;
    shutdownDelay = 0; # wait for as long as possible
  };

  system.stateVersion = "24.11";
}
