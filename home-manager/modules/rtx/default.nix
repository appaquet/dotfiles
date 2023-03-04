{ config, pkgs, libs, lib, ... }:

{
  home.packages = with pkgs; [
    rtx
  ];

  home.file.".tool-versions".source = ./tool-versions;

  xdg.configFile."fish/conf.d/rtx.fish".text = ''
    ${pkgs.rtx}/bin/rtx activate fish | source
  '';

  # TODO: Try to fix. Fails because it require git and awk, which aren't loaded at this point
  home.activation = {
    installRtxBinaries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.rtx}/bin/rtx install
    '';
  };
}
