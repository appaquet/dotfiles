{
  inputs,
  inputs',
  ...
}:

{
  imports = [
    inputs.nixantic.homeManagerModules.default
    ./nixantic.nix
    ./tools
    ../nono

    ./claude
    ./codex
    ./opencode
    ./pi
  ];

  config = {
    home.packages = [
      inputs'.llm-agents.packages.tokscale
      inputs'.llm-agents.packages.ccusage
    ];
  };
}
