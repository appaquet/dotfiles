{
  pkgs,
  lib,
  inputs',
  ...
}:

{
  imports = [
    ./fish.nix
    ./tmux
    ./git
    ./neovim
    ./mise.nix
    ./utils
    ./autojump.nix
    ./ssh.nix
  ];

  programs.home-manager.enable = true;

  # https://github.com/nix-community/nix-direnv#via-home-manager
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  home.packages =
    (with pkgs; [
      manix # nix doc cli searcher
      nix-output-monitor # better nix build output (nom)
      nixfmt-rfc-style
      nvd # nix package diff tool
      nix-tree # explore nix derivations dependencies (https://github.com/utdemir/nix-tree)
      cachix
      nix-index # nix-locate "libsomelib.so.0"
      comma

      tealdeer # rust version of tldr

      bat # cat replacement
      lsd # ls replacement
      hexyl

      fzf
      ripgrep
      ripgrep-all # supports pdf, docs, etc.
      fd # replacement for find

      dua
      bottom
      btop
      htop
      stress

      ookla-speedtest
      mtr
      gping
      fastfetch
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
    ]
    ++ lib.optionals (pkgs.stdenv.isDarwin || pkgs.stdenv.isx86_64) [
      inputs'.fzf-nix.packages.fzf-nix # fzf-nix, somehow doesn't work on linux arm
    ];
}
