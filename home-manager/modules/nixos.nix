{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nix-alien
    steam-run
  ];
}
