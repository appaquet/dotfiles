{
  pkgs,
  ...
}:

let
  agentic-proj-docs = pkgs.writeShellScriptBin "agentic-proj-docs" ''
    root="''${OPENCODE_ROOT:-''${CLAUDE_ROOT:-$(pwd)}}"
    proj="$root/proj"
    if [ -d "$proj" ]; then
      abs=$(readlink -f "$proj")
      echo "proj/ ($abs) files:"
      ls "$proj/"
    else
      echo "No `proj` symlink found. No project files."
    fi
  '';
in
{
  imports = [
    ../../../nixantic/home-manager.nix
    ./claude
    ./opencode
    ../nono
  ];

  config = {
    nixantic.sourceRoots = [ ./instructions ];

    home.packages = [
      agentic-proj-docs
      pkgs.codeburn
    ];
  };
}
