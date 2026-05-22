{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./claude
    ./opencode
    ../nono
  ];

  options.dotfiles.agentic.instructions.mode = lib.mkOption {
    type = lib.types.enum [ "legacy" "nixified" ];
    default = "legacy";
    description = ''
      Which instruction source to use for Claude and Opencode markdown files.
      - "legacy":  Source-tree markdown via out-of-store symlinks (current behavior).
      - "nixified": Store-backed generated markdown from the Nix template system.
    '';
  };

  config = {
    home.packages = [
      pkgs.codeburn
    ];
  };
}
