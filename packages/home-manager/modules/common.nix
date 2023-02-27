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
    tmux

    git

    bat # cat replacement
    hexyl

    fzf
    ripgrep

    dua
    bottom
    htop

    jq
    jless

    tealdeer # rust version of tldr

    kubectx
    kubectl
    k9s

    # rtx

    cargo

    any-nix-shell # allows using fish for `nix shell`
  ];
}
