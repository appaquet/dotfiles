{ pkgs, ... }:

{
  imports = [
    ./modules/common.nix
  ];

  home.packages = with pkgs; [
    rnix-lsp
  ];

  # home.file."hello-world.txt".text = ''
  #   Hello, world!
  # '';
  # home.file."some-file.txt".source = ./some-file.txt;

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "22.11";
}

