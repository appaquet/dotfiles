{
  # The substituter and key settings apply to both NixOS and nix-darwin, so they are published once and consumed by
  # name on either surface.
  flake.modules = {
    nixos.cachix = ./default.nix;
    darwin.cachix = ./default.nix;
  };
}
