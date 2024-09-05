{ unstablePkgs, lib, cfg, ... }:

let
  miseConfig = ''
    [settings]
    legacy_version_file = false
  '' +
  lib.optionals cfg.isNixos ''
    disable_tools = ["python", "node"]
  '';
in
{
  home.packages = [
    unstablePkgs.rtx
  ];

  home.file.".tool-versions".source = ./tool-versions;

  xdg.configFile."fish/conf.d/mise.fish".text = ''
    ${unstablePkgs.rtx}/bin/mise activate fish | source
  '';

  xdg.configFile."mise/config.toml".text = miseConfig;
}
