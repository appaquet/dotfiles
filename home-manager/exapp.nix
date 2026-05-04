{
  inputs,
  ...
}:

{
  imports = [
    inputs.secrets.homeManager.exomind
    ./modules/base.nix
    ./modules/agentic.nix
    ./modules/dev.nix
    ./modules/ghostty.nix
  ];

  dotfiles.neovim.devMode = true;

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "25.11";
}
