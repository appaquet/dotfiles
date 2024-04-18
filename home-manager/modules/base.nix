{ pkgs, inputs, ... }:

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

  # https://github.com/nix-community/nix-direnv#via-home-manager
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Notes: 
  #  - not everything is installed using nix. some tools are install via `mise` when different versions are required (see ./rtx/tool-versions)
  #  - to install an unstable package, use `unstablePkgs.<package-name>`
  home.packages = with pkgs; [
    manix # nix doc cli searcher
    nix-output-monitor # better nix build output (nom)
    nixpkgs-fmt
    inputs.fzf-nix.packages.${system}.fzf-nix # fzf-nix

    bat # cat replacement
    hexyl

    fzf
    ripgrep
    fd

    dua
    bottom
    btop
    htop
    stress

    ookla-speedtest
    mtr
    gping
    neofetch
    bandwhich
    dig
    whois

    jq
    jless

    zip
    unzip
    pigz
    gzip
    bzip2
    gnutar

    curl
    wget

    tealdeer # rust version of tldr

    rsync
    rclone
  ];
}
