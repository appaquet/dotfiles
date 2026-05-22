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
    type = lib.types.enum [
      "legacy"
      "nixified"
    ];
    default = "nixified";
    description = ''
      Which instruction source to use for Claude and Opencode markdown files.
      - "legacy":  Source-tree markdown via out-of-store symlinks (current behavior).
      - "nixified": Store-backed generated markdown from the Nix template system.
    '';
  };

  options.dotfiles.agentic.instructions.postProcess = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Apply post-processing to generated markdown files:
      - Remove empty and whitespace-only lines.
      - Remove trailing periods from all lines.
    '';
  };

  config = {
    home.packages = [
      pkgs.codeburn
    ];
  };
}
