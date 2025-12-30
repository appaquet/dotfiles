{ pkgs, ... }:
{
  imports = [
    ../modules/home-manager.nix
    ./apps.nix
    ./fonts.nix
    ./system.nix
    ../../nixos/modules/cachix.nix
  ];

  home-manager.users.appaquet = import ../../home-manager/mbpapp.nix;

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

  security.pam.services.sudo_local.touchIdAuth = true;

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
