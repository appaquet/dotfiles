{ pkgs, ... }:

{
  home.file.".local/utils".source = ./bin;

  programs.fish.interactiveShellInit = ''
    set -x PATH ~/.local/utils $PATH
  '';
}
