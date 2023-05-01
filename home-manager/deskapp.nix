{ pkgs, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/dev.nix
    ./modules/work.nix
    ./modules/vms.nix
    ./modules/nixos.nix
    ./modules/media.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "22.11";
}

