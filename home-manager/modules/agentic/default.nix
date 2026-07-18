{
  inputs,
  pkgs,
  ...
}:

let
  # npx wrapper for mcp use in coding agents
  mcp-npx = pkgs.writeShellScriptBin "mcp-npx" ''
    export PATH="$PATH:${pkgs.nodejs}/bin"
    npx "$@"
  '';
in
{
  imports = [
    inputs.harness.homeManagerModules.default
    ./claude
    ./opencode
    ../nono
  ];

  config = {
    nixantic.sourceRoots = [ ./instructions ];

    home.packages = [
      mcp-npx
      pkgs.codeburn
      pkgs.codex
    ];
  };
}
