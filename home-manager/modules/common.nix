{ pkgs, ... }:

{
  imports = [
    ./fish
    ./tmux
    ./git
    ./neovim
    ./rtx
    ./jira.nix
    ./utils
  ];

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    autojump

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

    rustup # don't install cargo, let rustup do the job here

    nix-output-monitor
    any-nix-shell # allows using fish for `nix shell`
  ];
}
