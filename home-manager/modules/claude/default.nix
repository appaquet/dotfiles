{ pkgs, config, lib, ... }:

let
  # We symlink here since it may be change by claude and I want to iterate
  mkClaudeSymlinks = paths:
    lib.listToAttrs (map (path: {
      name = ".claude/${path}";
      value = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/claude/${path}";
      };
    }) paths);
in
{
  home.file = mkClaudeSymlinks [
    "settings.json"
    "commands"
    "docs"
    "CLAUDE.md"
  ];

  home.packages = with pkgs; [
    claude-code
  ];
}
