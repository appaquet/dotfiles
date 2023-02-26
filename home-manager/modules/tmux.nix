{ config, pkgs, libs, ... }:

{
  programs.tmux = {
    enable = true;
    package = pkgs.tmux;
  };
}
