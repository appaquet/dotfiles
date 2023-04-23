{ pkgs, ... }:

{
  imports = [
    ./modules/common.nix
    ./modules/dev.nix
  ];

  programs.fish = {
    shellAbbrs = {
      vm = "sudo virsh ";
      vmls = "sudo virsh list --all";
      vmstart = "sudo virsh start";
      vmstop = "sudo virsh shutdown";
    };
  };

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "22.11";
}

