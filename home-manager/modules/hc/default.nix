{
  pkgs,
  inputs',
  ...
}:
{
  # Complete file: a partial keys.json silently unbinds every key it omits.
  # Pinned: new default bindings from later app versions need a manual refresh.
  xdg.configFile."herdr-app/keys.json".source = ./keys.json;

  home.packages = [
    pkgs.rodeo # TUI client for hc
    inputs'.llm-agents.packages.herdr-core
    inputs'.llm-agents.packages.herdr-app
  ];
}
