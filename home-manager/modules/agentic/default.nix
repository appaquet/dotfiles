{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nixantic.homeManagerModules.default
    ./nixantic.nix
    ./tools.nix
    ../nono

    ./claude
    ./opencode
    ./pi
  ];

  config = {
    home.packages = [
      pkgs.codex
      pkgs.antigravity-cli
      pkgs.codeburn
      pkgs.ccusage
    ];
  };
}
