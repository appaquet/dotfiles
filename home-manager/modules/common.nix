{ pkgs, ... }:

{
  imports = [
    ./fish.nix
    ./tmux
    ./git
    ./neovim
    ./rtx
    ./jira.nix
    ./utils
    ./autojump.nix
    ./rust.nix
  ];

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
    gh

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

    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))

    dive # docker container explorer

    nix-output-monitor
  ];
}
