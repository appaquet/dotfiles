{ pkgs, ... }:

{
  home.packages = with pkgs; [
    autojump
  ];

  programs.fish.interactiveShellInit = ''
    . ${pkgs.autojump}/share/autojump/autojump.fish
  '';
}

