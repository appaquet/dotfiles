{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    yt-dlp
    imagemagick
    mpv
    graphviz
  ];
}

