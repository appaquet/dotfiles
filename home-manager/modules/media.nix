{ pkgs, unstablePkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    youtube-dl
    imagemagick
    mpv
    graphviz
  ];
}

