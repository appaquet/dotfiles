{ ... }:

{
  imports = [
    ./modules/base.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "24.11";
}
