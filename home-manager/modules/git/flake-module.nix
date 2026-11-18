{ ... }:

{
  flake.modules.homeManager.git = ./default.nix;

  perSystem =
    { pkgs, ... }:
    {
      checks = import ./checks { inherit pkgs; };
    };
}
