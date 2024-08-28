{ inputs, config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../common.nix
      ../network_bridge.nix
      ../dev.nix
      ../docker.nix
      ./virt.nix
      ./virt-gpu.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    # Prevent intel nic from dropping after 1h
    # See https://www.reddit.com/r/buildapc/comments/xypn1m/network_card_intel_ethernet_controller_i225v_igc/
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  networking.hostName = "nixos"; # Define your hostname.

  # Drives (lsblk -f)
  fileSystems."/mnt/secondary" = {
    device = "/dev/disk/by-uuid/e154b94d-9f7e-4079-a80b-659e6ab532ca";
    fsType = "ext4";
  };
  fileSystems."/mnt/manjaro" = {
    device = "/dev/disk/by-uuid/7474df9e-0ada-475a-9a21-995fbdb988c4";
    fsType = "ext4";
  };

  # Networking
  networking.networkmanager.enable = true;
  networking.myBridge = {
    enable = true;
    interface = "eno1";
    lanIp = "192.168.2.99";
  };

  networking.hosts = {
    "100.81.111.43" = [ "localhost.humanfirst.ai" ];
  };

  # Display
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.appaquet = {
    isNormalUser = true;
    shell = pkgs.fish;
    description = "appaquet";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      #  thunderbird
    ];
  };
  programs.fish.enable = true;

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "appaquet";

  # Install firefox
  programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
}
