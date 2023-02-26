{ pkgs, ... }:

{
  imports = [
    ./modules/common.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "22.11";
}

