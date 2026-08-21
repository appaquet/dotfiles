{
  inputs,
  inputs',
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
    inputs.nixantic.homeManagerModules.default
    ./nixantic.nix
    ./claude
    ./opencode
    ./pi
    ./tmux-statusline.nix
    ../nono
  ];

  config = {
    home.packages = [
      mcp-npx
      inputs'.nixantic.packages.agentic-proj-docs
      inputs'.nixantic.packages.agentic-proj-create-adhoc
      pkgs.codex
      pkgs.antigravity-cli
      pkgs.codeburn
      pkgs.ccusage
    ];
  };
}
