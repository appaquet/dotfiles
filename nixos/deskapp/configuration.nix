{ pkgs, secrets, ... }:

{
  imports = [
    ../common.nix
    ../dev.nix
    ../docker.nix
    ../nasapp.nix
    ../network-bridge.nix
    ../ups/client.nix
    ../netconsole/sender.nix
    ./backups
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
    interface = "eno1";
    lanIp = "192.168.0.30";
  };
  networking.hosts = {
    "100.109.193.77" = [
      "localhost.humanfirst.ai"
      "istio-ingressgateway.istio-system.svc.cluster.local"
    ];
  };
  networking.firewall.enable = false;

  # NasAPP mounts
  nasapp = {
    enable = true;
    credentials = secrets.deskapp.nasappCifs;
    uid = "appaquet";
    gid = "users";
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

  # UPS
  power.myUps = {
    enable = true;
    shutdownDelay = 60; # suspend after 1 min on bat
    shutdownCmd = "${pkgs.systemd}/bin/systemctl suspend";
  };

  system.stateVersion = "24.05";
}
