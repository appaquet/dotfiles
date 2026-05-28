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
    description = "Apply post-processing to generated markdown: strips one trailing '.' from each line, and removes blank lines, whitespace-only lines, and lone '.' sentinel lines.";
  };

  config = {
    home.packages = [
      pkgs.codeburn
    ];
  };
}
