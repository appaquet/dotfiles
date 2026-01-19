{
  pkgs,
  config,
  lib,
  ...
}:

let
  # We symlink here since it may be change by claude and I want to iterate
  mkClaudeConfSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".claude/${path}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/claude/${path}";
        };
      }) paths
    );

  claude-code = pkgs.claude-code;

  # Override claude with overridden config dir. This prevents it from writing its config to
  # ~/.claude.json so that we can keep all claude config in ~/.claude.
  claude-wrapped = pkgs.writeShellScriptBin "claude" ''
    export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.claude"
    export CLAUDE_ROOT="''${CLAUDE_PROJECT_DIR:-$(pwd)}"
    exec ${claude-code}/bin/claude "$@"
  '';

  # Utility to list project docs (avoids shell expansion issues in skill commands)
  claude-proj-docs = pkgs.writeShellScriptBin "claude-proj-docs" ''
    if [ -d "''${CLAUDE_ROOT:-$(pwd)}/proj" ]; then
      ls "''${CLAUDE_ROOT:-$(pwd)}/proj/"
    else
      echo "No project files"
    fi
  '';
in
{
  home.file = mkClaudeConfSymlinks [
    "settings.json"
    "commands"
    "docs"
    "agents"
    "skills"
    "CLAUDE.md"
    "statusline.sh"
  ];

  home.packages = [
    claude-wrapped
    claude-proj-docs
    pkgs.socat # required for sandboxing
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.bubblewrap # required for sandboxing
  ];
}
