{ pkgs, unstablePkgs, ... }:

{
  imports = [
    ./fish.nix
    ./tmux
    ./git
    ./neovim
    ./rtx
    ./utils
    ./autojump.nix
    ./rust.nix
  ];

  programs.home-manager.enable = true;

  humanfirst.enable = true; # enable humanfirst goodies (git shortcuts, jira, etc.)
  humanfirst.identity.email = "app@humanfirst.ai";

  home.packages = with pkgs; [ # prefix with unstablePkgs to install from unstable
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
    tokei

    tealdeer # rust version of tldr

    kubectx
    k9s

    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))
    cloud-sql-proxy

    dive # docker container explorer

    nix-output-monitor
  ];
}
