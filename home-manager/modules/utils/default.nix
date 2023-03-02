{ pkgs, ... }:

{
  home.file.".local/dotfiles_bin".source = ./bin;

  home.sessionPath = [ "~/.local/dotfiles_bin" ];
}
