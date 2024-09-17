{ unstablePkgs, cfg, ... }:

let
  miseConfig = ''
    [settings]
    legacy_version_file = false
  '' +

  # should not install python or node via mise on nixos since 
  # it needs to compile from scratch.
  # we're better off using nixpkgs instead
  (if cfg.isNixos then ''
    disable_tools = ["python", "node"]
  '' else "");
in
{
  home.packages = [
    unstablePkgs.mise
  ];

  # global tools
  home.file.".tool-versions".text = ''
  '';

  xdg.configFile."fish/conf.d/mise.fish".text = ''
    ${unstablePkgs.mise}/bin/mise activate fish | source
  '';

  xdg.configFile."mise/config.toml".text = miseConfig;
}

