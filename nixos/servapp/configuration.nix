{ pkgs, secrets, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./virt
    ../common.nix
    ../dev.nix
    ../docker.nix
    ../network-bridge.nix
    # TODO: ../ups.nix
    ../nasapp.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = "1"; # VMs forward
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
  networking.networkmanager.enable = true;
  networking.myBridge = {
    enable = true;
    interface = "enp1s0";
    lanIp = "192.168.0.13";
  };
  networking.firewall.enable = false;

  # NasAPP mounts
  nasapp = {
    enable = true;
    credentials = secrets.servapp.nasappCifs;
    uid = "appaquet";
    gid = "users";
    shares = [
      {
        share = "backup_servapp"; # TODO: move to backup
        mount = "/mnt/backup_servapp";
      }
      {
        share = "video";
        mount = "/mnt/video";
      }
    ];
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
  hardware.pulseaudio.enable = false;
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11";
}
