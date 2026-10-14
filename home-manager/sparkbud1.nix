{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/agentic
  ];

  dotfiles.neovim.full = true;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
