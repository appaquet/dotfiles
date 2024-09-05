{ ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/linux.nix
    ./modules/dev.nix
    ./modules/work.nix
    ./modules/vms.nix
    ./modules/media.nix
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "23.11";
}

