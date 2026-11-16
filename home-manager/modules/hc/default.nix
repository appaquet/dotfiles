{
  pkgs,
  inputs',
  ...
}:
{
  home.packages = [
    pkgs.rodeo # TUI client for hc
    inputs'.llm-agents.packages.herdr-core
    inputs'.llm-agents.packages.herdr-app
  ];
}
