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
      experimental-features = [ "flakes" "nix-command" ];
      auto-optimise-store = true;
    };

    registry = {
      nixpkgs.flake = inputs.nixpkgs;
    };

    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      auto-optimise-store = true

      # assuming the builder has a faster internet connection
      builders-use-substitutes = true

      experimental-features = nix-command flakes
    '';
  };

  security.pam.enableSudoTouchIdAuth = true;

  programs = {
    fish.enable = true;
  };

  environment.shells = [ pkgs.fish ];

  users.users.appaquet = {
    home = "/Users/appaquet";
    shell = "${pkgs.fish}/bin/fish";
  };

  system.stateVersion = 4;
}
