{ pkgs }:

# npx wrapper for mcp use in coding agents
pkgs.writeShellScriptBin "mcp-npx" ''
  export PATH="$PATH:${pkgs.nodejs}/bin"
  npx "$@"
''
