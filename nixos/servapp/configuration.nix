{
  ...
}:

{
  imports = [
    ./backups.nix
    ./media.nix
    ./datasets.nix
    ./monitoring.nix
    ./samba.nix
    ./hardware-configuration.nix
    ../modules/common.nix
    ../modules/dev.nix
    ../modules/docker.nix
    ../modules/dotblip.nix
    ../modules/network-bridge.nix
    ../modules/restic/backup.nix
    ../modules/restic/server.nix
    ../modules/ups/client.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "servapp";
  networking.hostId = "93ce7521";

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

  users = {
    users = {
      chloe = {
        isSystemUser = true;
        group = "users";
      };

      homeassistant = {
        isSystemUser = true;
        group = "users";
      };

      andre = {
        isSystemUser = true;
        group = "users";
      };
    };

    groups = {
      media.members = [
        "appaquet"
        "chloe"
        "andre"
      ];

      photos.members = [
        "appaquet"
        "immich"
        "chloe"
      ];

      videos.members = [
        "appaquet"
        "chloe"
        "andre"
      ];
    };
  };

  services.syncthing = {
    enable = true;
    user = "appaquet";
    group = "users";
    dataDir = "/home/appaquet";
    guiAddress = "100.100.243.45:8384";

    overrideDevices = false;
    overrideFolders = false;

    # tailscale-only, no global/local announce
    settings.options = {
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
      natEnabled = false;
    };
  };

  dotblip = {
    enable = true;
    reporters = {
      restic = {
        enable = true;
        localBackups = [ "home" ];
        interval = 3600;
      };
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
