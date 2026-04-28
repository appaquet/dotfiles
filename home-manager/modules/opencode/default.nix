{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkOpencodeConfSymlinks =
    prefix: basePath: paths:
    lib.listToAttrs (
      map (path: {
        name = "${prefix}/${path}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/${basePath}/${path}";
        };
      }) paths
    );
in
{
  home.file = (
    mkOpencodeConfSymlinks ".config/opencode" "opencode" [
      "commands"
      "agents"
      "opencode.json"
    ]
  );

  home.packages = [
    pkgs.opencode
  ];
}
