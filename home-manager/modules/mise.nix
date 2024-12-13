{ unstablePkgs, cfg, ... }:

let
  miseConfig =
    ''
      [settings]
      legacy_version_file = false
    ''
    +

      # should not install python or node via mise on nixos since
      # it needs to compile from scratch.
      # we're better off using nixpkgs instead
      (
        if cfg.isNixos then
          ''
            disable_tools = ["python", "node"]
          ''
        else
          ""
      );
in
{
  home.packages = [
    unstablePkgs.mise
  ];

  # global tools (none anymore since we're using nixpkgs)
  home.file.".tool-versions".text = '''';

  programs.fish.interactiveShellInit = ''
    ${unstablePkgs.mise}/bin/mise activate fish | source
  '';

  xdg.configFile."mise/config.toml".text = miseConfig;
}
