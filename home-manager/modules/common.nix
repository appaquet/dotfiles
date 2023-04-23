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
  ];

  programs.home-manager.enable = true;

  humanfirst.enable = true; # enable humanfirst goodies (git shortcuts, jira, etc.)
  humanfirst.identity.email = "app@humanfirst.ai";

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Notes: 
  #  - not everything is installed using nix. some tools are install via `rtx` when different versions are required (see ./rtx/tool-versions)
  #  - to install an unstable package, use `unstablePkgs.<package-name>`
  home.packages = with pkgs; [
    manix # nix doc cli searcher
    nix-output-monitor # better nix build output (nom)

    git

    bat # cat replacement
    hexyl

    fzf
    ripgrep

    dua
    bottom
    htop
    ookla-speedtest
    mtr

    jq
    jless

    tealdeer # rust version of tldr

    rsync
    rclone
  ];
}
