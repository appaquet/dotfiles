{ pkgs, ... }:

{
  home.file.".local/utils".source = ./bin;

  programs.fish.interactiveShellInit = ''
    set -x PATH ~/.local/utils $PATH
  '';

  # TODO: Figure out why this isn't working. The issue is that the file it gets added in cannot get reloaded multiple times. 
  # It uses a var that gets inherited from the parent scope, so it can't be reloaded when updated later.
  # https://github.com/nix-community/home-manager/issues/3417
  home.sessionPath = [ "~/.local/YELLOW" ];
}
