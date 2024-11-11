{ pkgs, unstablePkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    unstablePkgs.yt-dlp
    imagemagick
    graphviz
  ];
}

