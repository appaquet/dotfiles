{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/vms.nix
    ./modules/git/jujutsu.nix # unstable
    ./modules/media.nix
    ./modules/docker.nix
    ./modules/vpn.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "24.11";
}
