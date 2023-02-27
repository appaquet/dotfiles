{ pkgs, ... }:

{
  imports = [
    ./modules/common.nix
  ];

  home.packages = with pkgs; [
    rnix-lsp
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "22.11";
}

