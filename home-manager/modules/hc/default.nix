{
  inputs',
  ...
}:
{
  home.packages = [
    inputs'.llm-agents.packages.herdr-core
    inputs'.llm-agents.packages.herdr-app
  ];
}
