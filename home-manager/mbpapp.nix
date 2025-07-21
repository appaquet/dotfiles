{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/claude.nix
    ./modules/dev.nix
    ./modules/docker.nix
    ./modules/ghostty.nix
    ./modules/media.nix
    ./modules/wezterm.nix
    ./modules/work
  ];

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}
