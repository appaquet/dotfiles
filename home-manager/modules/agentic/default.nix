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

  tmuxStatusline = "${import ./tmux-statusline.nix { inherit pkgs; }}/bin/tmux-statusline";
in
{
  imports = [
    inputs.harness.homeManagerModules.default
    ./claude
    ./opencode
    ./tmux-statusline.nix
    ../nono
  ];

  config = {
    _module.args.tmuxStatusline = tmuxStatusline;

    nixantic.sourceRoots = [ ./instructions ];

    home.packages = [
      mcp-npx
      pkgs.codeburn
      pkgs.codex
    ];
  };
}
