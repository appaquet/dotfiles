{ inputs, ... }:

{
  imports = with inputs.self.modules.homeManager; [
    base
  ];

  dotfiles.neovim.full = false;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "24.11";
}
