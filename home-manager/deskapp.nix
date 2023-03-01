{ pkgs, ... }:

{
  imports = [
    ./modules/common.nix
  ];

  home.packages = with pkgs; [
    nil # nix lsp
  ];

  programs.fish = {
    shellAbbrs = {
      vm = "sudo virsh ";
      vml = "sudo virsh list --all";
      vmls = "sudo virsh list --all";
      vmstart = "sudo virsh start ";
      vmstop = "sudo virsh shutdown ";
      vmshut = "sudo virsh shutdown ";
    };
  };

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "22.11";
}

