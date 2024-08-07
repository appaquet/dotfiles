{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nix-alien

    tailscale
    gnumake
    nodejs # needed for copilot

    bintools
  ];

}
