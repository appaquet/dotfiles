{
  config,
  lib,
  pkgs,
  inputs',
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
    [ -f ".nono/pre.sh" ] && . ".nono/pre.sh"
    PROFILE=$(maymaybe-profile opencode)
    exec nono run --profile "$PROFILE" --allow-cwd -- maymaybe-in ${opencode-wrapped}/bin/opencode "$@"
  '';

  opencode = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_CONFIG=${./opencode.json}
    ${opencode-wrapped}/bin/opencode "$@"
  '';

in
{
  home.file =
    (mkOpencodeConfSymlinks ".config/opencode" "opencode" [
      "commands"
      "agents"
      "tui.json"
    ])
    // {
      ".config/opencode/plugins/ccmon.ts".source = "${inputs'.ccmon.packages.opencode-plugin}/ccmon.ts";
    };

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
        "$HOME/.local/state/ccmon" # ccmon plugin writes status there
      ];
    };
    network.block = false;
  };
}
