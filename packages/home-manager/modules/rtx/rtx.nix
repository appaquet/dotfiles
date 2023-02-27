{ config, pkgs, libs, ... }:

{
  home.packages = with pkgs; [
    rtx
  ];

  home.file.".tool-versions".source = ./tool-versions;

  xdg.configFile."fish/conf.d/rtx.fish".text = ''
    rtx activate fish | source
  '';
}
