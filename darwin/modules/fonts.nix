{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    jetbrains-mono
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];
}
