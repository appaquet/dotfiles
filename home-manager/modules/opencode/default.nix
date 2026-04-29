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

  opencode-wrapped = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_ENABLE_EXA=1
    ${pkgs.opencode}/bin/opencode "$@"
  '';

  nono-opencode = pkgs.writeShellScriptBin "nono-opencode" ''
    export OPENCODE_CONFIG=${./opencode-nono.json}
    nono run --profile ${./nono-profile.json} --allow-cwd -- ${opencode-wrapped}/bin/opencode "$@"
  '';

  opencode = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_CONFIG=${./opencode.json}
    ${opencode-wrapped}/bin/opencode "$@"
  '';

in
{
  home.file = (
    mkOpencodeConfSymlinks ".config/opencode" "opencode" [
      "commands"
      "agents"
    ]
  );

  home.packages = [
    nono-opencode
    opencode
  ];
}
