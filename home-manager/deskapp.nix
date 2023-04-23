{ pkgs, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/dev.nix
    ./modules/hf.nix
    ./modules/vms.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "22.11";
}

