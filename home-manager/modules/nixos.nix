{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nix-alien
    steam-run

    nodejs # needed for copilot
  ];
}
