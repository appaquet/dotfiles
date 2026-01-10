{ pkgs, ... }:
{
  imports = [
    ./apps.nix
    ./fonts.nix
    ./system.nix
    ../../nixos/modules/cachix.nix
  ];

  nix = {
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
        "fetch-closure"
      ];
      auto-optimise-store = false; # TODO: Turn back on when https://github.com/NixOS/nix/issues/7273
      keep-outputs = true;
      keep-derivations = true;
      builders-use-substitutes = true;
      trusted-users = [
        "root"
        "@admin"
      ];
    };
  };

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true; # enables pam_reattach for Touch ID in tmux
  };

  time.timeZone = "America/Toronto";

  networking.localHostName = "mbpapp";

  environment.systemPackages = with pkgs; [
    fish
  ];

  programs = {
    fish.enable = true;
  };

  users.users.appaquet = {
    home = "/Users/appaquet";
    shell = "${pkgs.fish}/bin/fish";
  };
  system.primaryUser = "appaquet"; # apply user settings to appaquet (root otherwise)

  system.stateVersion = 5;
}
