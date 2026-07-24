{ ... }:

{
  imports = [
    ./modules/base.nix
  ];

  dotfiles.neovim.full = true;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
