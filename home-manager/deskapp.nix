{ inputs, ... }:

{
  imports = [
    inputs.secrets.homeManager.exomind
    ./modules/base.nix
    ./modules/agentic
    ./modules/dev.nix
    ./modules/docker.nix
    ./modules/media.nix
    ./modules/vms.nix
    ./modules/vpn.nix
    ./modules/work
  ];

  dotfiles.nono.profiles.machine.filesystem.allow = [
    "$HOME/Projects"
    "$HOME/Work"
  ];

  dotfiles.neovim.devMode = true;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "23.11";
}
