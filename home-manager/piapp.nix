{ inputs, ... }:

{
  imports = [
    inputs.humanfirst-dots.homeManagerModule
    inputs.secrets.homeManager.common
    ./modules/base.nix
  ];

  dotfiles.neovim.full = false;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "24.11";
}
