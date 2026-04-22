{
  pkgs,
  config,
  lib,
  ...
}:

let
  mkOpencodeConfSymlinks = prefix: basePath: paths: lib.listToAttrs (
    map (path: {
      name = "${prefix}/${path}";
      value = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/${basePath}/${path}";
      };
    }) paths
  );
in
{
  # Commands: OpenCode reads ~/.config/opencode/commands/*.md globally
  # Agents: OpenCode reads ~/.config/opencode/agents/*.md globally
  # (skills are already covered by ~/.claude/skills/ which OpenCode reads natively)
  home.file = (mkOpencodeConfSymlinks ".config/opencode" "opencode" [
    "commands"
    "agents"
  ]) // {
    ".config/opencode/opencode.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/opencode/opencode.json";
    };
  };
}
