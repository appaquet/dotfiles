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
    ./jira.nix
  ];

  programs.home-manager.enable = true;

  humanfirst.enable = true; # enable humanfirst goodies (git shortcuts, jira, etc.)
  humanfirst.identity.email = "app@humanfirst.ai";

  # Notes: 
  #  - not everything is installed using nix. some tools are install via `rtx` when different versions are required (see ./rtx/tool-versions)
  #  - to install an unstable package, use `unstablePkgs.<package-name>`
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
    ookla-speedtest

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
