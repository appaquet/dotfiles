{ inputs, ... }:

{
  imports = with inputs.self.modules.homeManager; [
    base
    agentic
  ];

  programs.direnv.config = {
    whitelist = {
      prefix = [
        "/home/appaquet/dotcore"
      ];
    };
  };

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
