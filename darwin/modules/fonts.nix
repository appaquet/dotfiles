{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];
}
