{ config, ... }:

{
  home.file.".local/utils".source = ./bin;

  home.sessionPath = [ "${config.home.homeDirectory}/.local/utils" ];
}
