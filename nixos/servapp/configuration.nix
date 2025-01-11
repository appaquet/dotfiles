{ secrets, ... }:

{
  imports = [
    ../common.nix
    ../dev.nix
    ../docker.nix
    ../nasapp.nix
    ../network-bridge.nix
    #../ups.nix
    ./backup.nix
    ./hardware-configuration.nix
    ./virt
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  # NasAPP mounts
  nasapp = {
    enable = true;
    credentials = secrets.servapp.nasappCifs;
    uid = "appaquet";
    gid = "users";
    shares = [
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

  system.stateVersion = "24.11";
}
