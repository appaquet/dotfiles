{ ... }:

{
  imports = [
    ./modules/base
    ./modules/agentic
    ./modules/dev.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
