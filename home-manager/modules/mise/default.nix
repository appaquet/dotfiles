{ unstablePkgs, lib, cfg, ... }:

let
  miseConfig = ''
    [settings]
    legacy_version_file = false
  '' +

  # should not install python or node via mise on nixos since 
  # it needs to compile from scratch.
  # we're better of using nixpkgs instead
  (if cfg.isNixos then ''
    disable_tools = ["python", "node"]
  '' else "");
in
{
  home.packages = [
    unstablePkgs.rtx
  ];

  home.file.".tool-versions".source = ./tool-versions;

  xdg.configFile."fish/conf.d/mise.fish".text = ''
  ${unstablePkgs.rtx}/bin/mise activate fish | source
  '' ;

  xdg.configFile."mise/config.toml".text = miseConfig;
}

