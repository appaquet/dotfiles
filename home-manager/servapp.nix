{ pkgs, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/vms.nix
    ./modules/media.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "23.11";
}

