{ pkgs, ... }:

{
  imports = [
    ./cachix.nix
  ];

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
        "fetch-closure"
      ];
      auto-optimise-store = true;
      keep-outputs = true;
      keep-derivations = true;
      builders-use-substitutes = true; # allow use of cached builds, require fast internet
      trusted-users = [ "@wheel" ];
    };
  };

  users.users.appaquet = {
    isNormalUser = true;
    shell = pkgs.fish;
    description = "appaquet";
    initialPassword = "carpediem";

    homeMode = "0755"; # virt access to var files

    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNXBK1YpLeuIKx+tpVLpZOhKbMcqLeMx15SvcBG0jcR appaquet@gmail.com"
    ];
  };
  programs.fish.enable = true;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;

  # Enable linger
  # See https://discourse.nixos.org/t/adding-nixos-option-for-systemd-user-lingering/28762/3
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/appaquet"
  ];

  # Clean tmp dir on boot
  boot.tmp.cleanOnBoot = true;

  # Allow running external dynamically binaries
  # nix-ld replaces interpreter and automatically link with nix libs
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
  ];

  # System wide packages
  environment.systemPackages = with pkgs; [
    lsof
    pciutils # lspci
    usbutils # lsusb
  ];

  # Some programs (ex: Go) expects /etc/mime.types
  environment.etc."mime.types".source = "${pkgs.mailcap}/etc/mime.types";

  # Run fstrim weekly
  services.fstrim.enable = true;

  # Networking
  services.tailscale.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false; # cause more issues than it solves
}
