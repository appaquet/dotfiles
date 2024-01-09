{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nix-alien

    tailscale
    gnumake

    bintools
  ];

}
