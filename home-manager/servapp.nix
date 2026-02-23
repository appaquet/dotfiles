{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/claude
    ./modules/dev.nix
    ./modules/docker.nix
    ./modules/media.nix
    ./modules/vms.nix
    ./modules/vpn.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
