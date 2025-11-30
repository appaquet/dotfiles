{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    yt-dlp
    imagemagick
    graphviz

    ripgrep-all # supports pdf, docs, etc.
  ];
}
