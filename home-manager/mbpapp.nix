{  ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/dev.nix
    ./modules/work.nix
    ./modules/media.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}

