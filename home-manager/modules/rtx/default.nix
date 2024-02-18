{ unstablePkgs, ... }:

{
  home.packages = [
    unstablePkgs.rtx
  ];

  home.file.".tool-versions".source = ./tool-versions;

  xdg.configFile."fish/conf.d/mise.fish".text = ''
    ${unstablePkgs.rtx}/bin/mise activate fish | source
  '';

  home.shellAliases = {
    rtx = "mise";
  };
}
