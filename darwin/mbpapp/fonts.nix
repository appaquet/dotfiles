{ pkgs, ... }:

{
  fonts.fonts = with pkgs; [
    jetbrains-mono
    fira-code
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
  ];

  fonts.fontDir.enable = true;
}