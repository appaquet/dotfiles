{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/agentic
  ];

  dotfiles.neovim.full = true;

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
