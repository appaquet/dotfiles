{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/claude
    ./modules/dev.nix
    ./modules/docker.nix
    ./modules/ghostty.nix
    ./modules/media.nix
    ./modules/mise.nix
    ./modules/work
  ];

  dotfiles.neovim.devMode = true;

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}
