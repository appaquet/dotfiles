{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    jetbrains-mono
    fira-code
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
  ];
}
