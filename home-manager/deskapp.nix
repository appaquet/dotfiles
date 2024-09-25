{ secrets, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/dev.nix
    ./modules/work
    ./modules/vms.nix
    ./modules/media.nix
    ./modules/exo.nix
    secrets.homeManager.nasappCifs
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "23.11";
}

