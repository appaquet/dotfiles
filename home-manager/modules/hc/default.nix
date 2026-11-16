{
  pkgs,
  inputs',
  ...
}:
{
  imports = [ ./app-module.nix ];

  dotfiles.herdr-app.settings = {
    font = "FiraCode Nerd Font";
  };

  xdg.configFile."herdr-app/keys.json".source = ./keys.json;

  home.packages = [
    pkgs.rodeo # TUI client for hc
    inputs'.llm-agents.packages.herdr-core
    inputs'.llm-agents.packages.herdr-app
  ];
}
