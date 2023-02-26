{ pkgs, ... }:

{
  imports = [
    ./fish.nix
    ./tmux.nix
    ./git/git.nix
    ./neovim/neovim.nix
  ];

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    jq
    bat
    fzf
    any-nix-shell
  ];
}