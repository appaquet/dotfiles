{ pkgs, ... }:

{
  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [ "flakes" "nix-command" "fetch-closure" ];
      auto-optimise-store = true;
      keep-outputs = true;
      keep-derivations = true;
      trusted-users = [ "@wheel" ];
    };
  };

  users.users.appaquet = {
    isNormalUser = true;
    shell = pkgs.fish;
    description = "appaquet";

    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNXBK1YpLeuIKx+tpVLpZOhKbMcqLeMx15SvcBG0jcR appaquet@gmail.com"
    ];
  };
  programs.fish.enable = true;

  # Allow running external dynamically binaries
  # nix-ld replaces interpreter and automatically link with nix libs
  # `nix-alien-ld` can be used to run binaries
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
  ];

  # System wide packages
  environment.systemPackages = with pkgs; [
    lsof
  ];

  # Run fstrim weekly
  services.fstrim.enable = true;

  services.tailscale.enable = true;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;
}
