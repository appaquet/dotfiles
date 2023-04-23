{ pkgs, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/dev.nix
    ./modules/hf.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "22.11";
}

