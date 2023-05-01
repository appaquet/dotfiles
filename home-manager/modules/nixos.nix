{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # allow patching binaries
    nix-alien
    nix-ld

    tailscale
    gnumake
  ];

}
