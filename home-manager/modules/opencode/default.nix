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
    nono run --profile opencode --allow-cwd -- ${opencode-wrapped}/bin/opencode "$@"
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

  dotfiles.nono.profiles.opencode = {
    meta.version = "1.0.0";
    extends = "coding-agent";
    filesystem = {
      read = [ "$HOME/.claude" ];
      allow = [
        "$HOME/.config/opencode"
        "$HOME/.local/share/opencode"
        "$HOME/.cache/opencode"
        "$HOME/.local/state/opencode"
        "$HOME/.config/fish"
        "$HOME/.local/share/fish"
        "/tmp"
      ];
      read_file = [ ];
      write_file = [ ];
    };
    network.block = false;
    workdir.access = "readwrite";
  };
}
