{ pkgs, ... }:

let
  miseConfig = ''
    [settings]
    legacy_version_file = false
  ''
  +
    # Disable python/node on NixOS to use nixpkgs versions
    # and prevent mise from compiling them from source
    (
      if pkgs.stdenv.isLinux then
        ''
          disable_tools = ["python", "node"]
        ''
      else
        ""
    );
in
{
  home.packages = with pkgs; [
    mise
  ];

  # global tools (none anymore since we're using nixpkgs)
  home.file.".tool-versions".text = "";

  programs.fish.interactiveShellInit = ''
    ${pkgs.mise}/bin/mise activate fish | source
  '';

  xdg.configFile."mise/config.toml".text = miseConfig;
}
