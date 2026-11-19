{ inputs, ... }:

{
  imports = with inputs.self.modules.homeManager; [
    base
    agentic
    dev
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
