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
    ../modules/restic/backup.nix
    ./hardware-configuration.nix
    ./adguardhome.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "servapp";

  # Networking
  networking.myBridge = {
    enable = true;
    interface = "enp1s0";
    lanIp = "192.168.0.13";
  };
  networking.firewall.enable = false;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-exit-node" ];
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
      schedule = "daily";
    };
  };

  # Programs & services
  programs.firefox.enable = true;
  services.openssh.enable = true;

  # UPS
  power.myUps = {
    enable = true;
    shutdownDelay = 300; # shutdown after 5 mins on bat
  };

  # GUI specialisation (switch with: nixos-rebuild switch --specialisation gui)
  specialisation.gui.configuration = {
    # Display
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.xfce.enable = true;
    services.xserver.xkb.layout = "us";
    services.xserver.xkb.variant = "";
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "appaquet";

    # Sound with pipewire
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  system.stateVersion = "25.11";
}
