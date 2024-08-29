{ pkgs, config, lib, inputs, ... }:
{
  imports = [
    ./fonts.nix
  ];

  environment.systemPackages = with pkgs; [
    fish
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  nix = {
    package = pkgs.nix;

    settings = {
      experimental-features = [ "flakes" "nix-command" "fetch-closure" ];
      auto-optimise-store = true;
      keep-outputs = true;
      keep-derivations = true;
      builders-use-substitutes = true; # allow use of cached builds, require fast internet
    };

    registry = {
      nixpkgs.flake = inputs.inputs.nixpkgs;
    };
  };

  security.pam.enableSudoTouchIdAuth = true;

  programs = {
    fish.enable = true;
  };

  users.users.appaquet = {
    home = "/Users/appaquet";
    shell = "${pkgs.fish}/bin/fish";
  };

  system.stateVersion = 4;
}
