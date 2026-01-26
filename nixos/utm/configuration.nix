{ pkgs, ... }:

{
  imports = [
    ../modules/common.nix
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "utm";

  networking.networkmanager.enable = true;

  networking.firewall.enable = false;
  services.openssh.enable = true;

  programs.firefox.enable = true;

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    # xwayland.enable = true; # Enabled by default, but good to keep in mind
  };

  # Hint Electon apps to use Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Essential system packages
  environment.systemPackages = with pkgs; [
    waybar # The status bar
    dunst # Notification daemon
    libnotify # Required for dunst
    swww # Wallpaper daemon (or hyprpaper)
    rofi # App launcher
    kitty # Default terminal (Hyprland's default is kitty)
    networkmanagerapplet # Wifi tray icon
    #dolphin               # filemanager
  ];

  # Optional: Enable a Display Manager (SDDM is common for Wayland)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Fonts (Waybar needs these for icons)
  fonts.packages = with pkgs; [
    nerd-fonts.symbols-only
    nerd-fonts.fira-code
  ];

  system.stateVersion = "25.01";
}
