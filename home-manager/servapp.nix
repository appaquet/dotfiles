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
    ./modules/mise.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "24.11";
}
