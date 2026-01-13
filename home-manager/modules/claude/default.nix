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
    exec ${claude-code}/bin/claude "$@"
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
    pkgs.socat # required for sandboxing
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.bubblewrap # required for sandboxing
  ];
}
