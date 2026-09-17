{
  inputs,
  inputs',
  pkgs,
  ...
}:

{
  imports = [
    inputs.nixantic.homeManagerModules.default
    ./nixantic.nix
    ./tools
    ../nono

    ./claude
    ./opencode
    ./pi
  ];

  config = {
    home.packages = [
      inputs'.llm-agents.packages.codex
      inputs'.llm-agents.packages.tokscale
      inputs'.llm-agents.packages.ccusage
    ];
  };
}
