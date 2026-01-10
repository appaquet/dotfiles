{
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.humanfirst-dots.homeManagerModule
    inputs.secrets.homeManager.common
    inputs.nix-index-database.homeModules.default
    ./fish
    ./tmux
    ./git
    ./neovim
    ./utils
    ./autojump.nix
    ./ssh.nix
    ./ssh-agent.nix
  ];

  programs.home-manager.enable = true;

  # SSH agent socket persistence for tmux sessions
  dotfiles.ssh-agent.enable = true;

  # https://github.com/nix-community/nix-direnv#via-home-manager
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # pre-built nix-index (nix-locate <file>, comma (,))
  programs.nix-index-database.comma.enable = true;
  programs.nix-index.enable = true;

  home.packages =
    (with pkgs; [
      manix # nix doc cli searcher
      nix-output-monitor # better nix build output (nom)
      nixfmt-rfc-style
      nvd # nix package diff tool
      nix-tree # explore nix derivations dependencies (https://github.com/utdemir/nix-tree)
      cachix

      tealdeer # rust version of tldr

      bat # cat replacement
      lsd # ls replacement
      hexyl

      fzf
      ripgrep
      fd # replacement for find

      dua
      bottom
      btop
      htop
      stress

      ookla-speedtest
      mtr
      gping
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
      bc
      killall

      curl
      wget
      socat

      rsync
      rclone
    ])
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.libtree # recursive ldd
      pkgs.dool # dstat alternative, only on linux
      pkgs.wol # wake on lan
      pkgs.iotop
    ]
    ++ lib.optionals (pkgs.stdenv.isDarwin || pkgs.stdenv.isx86_64) [
      pkgs.fzf-nix # fzf-nix, somehow doesn't work on linux arm
    ];
}
