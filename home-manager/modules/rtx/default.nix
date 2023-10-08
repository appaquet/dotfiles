{ unstablePkgs, ... }:

{
  home.packages = [
    unstablePkgs.rtx
  ];

  home.file.".tool-versions".source = ./tool-versions;

  xdg.configFile."fish/conf.d/rtx.fish".text = ''
    ${unstablePkgs.rtx}/bin/rtx activate fish | source
  '';
}
