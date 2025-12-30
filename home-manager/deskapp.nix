{ inputs, ... }:

{
  imports = [
    inputs.humanfirst-dots.homeManagerModule
    inputs.secrets.homeManager.common
    ./modules/base.nix
    ./modules/claude
    ./modules/dev.nix
    ./modules/docker.nix
    ./modules/media.nix
    ./modules/vms.nix
    ./modules/vpn.nix
    ./modules/mise.nix
    ./modules/work
  ];

  dotfiles.neovim.devMode = true;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "23.11";
}
