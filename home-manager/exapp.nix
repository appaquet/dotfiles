{
  inputs,
  ...
}:

{
  imports = [
    inputs.secrets.homeManager.exomind
    ./modules/base.nix
    ./modules/claude
    ./modules/dev.nix
    ./modules/ghostty.nix
  ];

  dotfiles.neovim.devMode = true;

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "25.11";
}
