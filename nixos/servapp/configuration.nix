{ secrets, ... }:

{
  imports = [
    ../common.nix
    ../dev.nix
    ../docker.nix
    ../nasapp.nix
    ../network-bridge.nix
    ../ups/client.nix
    ../netconsole/sender.nix
    ./backup.nix
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
      {
        share = "kiwix";
        mount = "/mnt/kiwix";
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
