{
  pkgs,
  config,
  ...
}:

{
  imports = [
    ../modules/common.nix
    ../modules/dev.nix
    ../modules/docker.nix
    ../modules/dotblip.nix
    ../modules/nasapp.nix
    ../modules/netconsole/sender.nix
    ../modules/network-bridge.nix
    ../modules/restic/backup.nix
    ../modules/ups/client.nix
    ./gpu-switch.nix
    ./ha-ctrl.nix
    ./hardware-configuration.nix
    ./virt
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelParams = [
    # Prevent intel nic from dropping after 1h
    # See https://www.reddit.com/r/buildapc/comments/xypn1m/network_card_intel_ethernet_controller_i225v_igc/
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  networking.hostName = "deskapp";

  # Drives (lsblk -f)
  fileSystems."/mnt/secondary" = {
    device = "/dev/disk/by-uuid/e154b94d-9f7e-4079-a80b-659e6ab532ca";
    fsType = "ext4";
  };
  fileSystems."/mnt/tertiary" = {
    device = "/dev/disk/by-uuid/1bece886-d8b2-4fd4-a057-990de4ba308c";
    fsType = "ext4";
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  # Networking
  networking.myBridge = {
    enable = true;
    interface = "enp6s0";
    lanIp = "192.168.0.30";
  };
  networking.hosts = {
    "100.109.193.77" = [
      "localhost.humanfirst.ai"
      "istio-ingressgateway.istio-system.svc.cluster.local"
    ];
  };
  networking.firewall.enable = false;

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

  programs.chromium = {
    enable = true;
    extensions = [
      "fcoeoabgfeneiglbffodgkkbkcdhcgfn" # claude
    ];
  };
  environment.systemPackages = with pkgs; [
    chromium
  ];

  sops.secrets.nasapp_cifs.sopsFile = config.sops.secretsFiles.home;
  nasapp = {
    enable = true;
    credentials = config.sops.secrets.nasapp_cifs.path;
    uid = "appaquet";
    gid = "users";
  };

  restic-backup = {
    enable = true;
    sopsFile = config.sops.secretsFiles.home;

    backups.home = {
      paths = [ "/home/appaquet" ];
      schedule = "*:0/30";
    };

    backups.vms = {
      paths = [
        "/mnt/secondary/vms"
      ];
      schedule = "weekly";
      pruneOpts = [
        "--keep-weekly 4"
      ];
    };
  };

  dotblip = {
    reporters = {
      restic = {
        enable = true;
        localBackups = [
          "home"
          "vms"
        ];
        interval = 3600;
      };
    };
  };

  # UPS
  power.myUps = {
    enable = true;
    shutdownDelay = 60; # suspend after 1 min on bat
    shutdownCmd = "${pkgs.systemd}/bin/systemctl suspend";
  };

  system.stateVersion = "24.05";
}
