{
  inputs,
  pkgs,
  ...
}:

let
  agentic-proj-docs = pkgs.writeShellScriptBin "agentic-proj-docs" ''
    print_proj_files() {
      local label="$1"
      local proj="$2"
      local abs

      abs=$(readlink -f "$proj")
      echo "$label ($abs) files:"
      ls "$proj/"
    }

    if [ -e "./proj" ] || [ -L "./proj" ]; then
      if [ -d "./proj" ]; then
        print_proj_files "./proj" "./proj"
        exit 0
      fi

      echo "Invalid local ./proj: expected a directory or symlink to a directory" >&2
      exit 1
    fi

    if [ -n "''${OPENCODE_ROOT:-}" ] && [ -d "$OPENCODE_ROOT/proj" ]; then
      print_proj_files "$OPENCODE_ROOT/proj" "$OPENCODE_ROOT/proj"
      exit 0
    fi

    if [ -n "''${CLAUDE_ROOT:-}" ] && [ -d "$CLAUDE_ROOT/proj" ]; then
      print_proj_files "$CLAUDE_ROOT/proj" "$CLAUDE_ROOT/proj"
      exit 0
    fi

    echo "No project files found."
  '';

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
      agentic-proj-docs
      mcp-npx
      pkgs.codeburn
    ];
  };
}
