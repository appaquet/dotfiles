{ pkgs, ... }:

{
  home.file.".local/utils".source = ./bin;

  home.sessionPath = [ "~/.local/utils" ];
}
