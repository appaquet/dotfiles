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
  };

  options.dotfiles.agentic.instructions.postProcess = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Apply post-processing to slim down the generated markdown files.";
  };

  config = {
    home.packages = [
      pkgs.codeburn
    ];
  };
}
