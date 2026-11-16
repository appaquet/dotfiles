{
  inputs',
  ...
}:

{
  imports = [
    ./nixantic.nix
    ./tools

    ./claude
    ./codex
    ./opencode
    ./pi
  ];

  config = {
    dotfiles.nono.enable = true;

    home.packages = [
      inputs'.llm-agents.packages.tokscale
      inputs'.llm-agents.packages.ccusage
    ];
  };
}
