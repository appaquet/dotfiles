{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/dev.nix
    ./modules/claude
    ./modules/opencode
  ];

  dotfiles.neovim.full = true;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
