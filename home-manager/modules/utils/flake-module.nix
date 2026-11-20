{
  flake.modules.homeManager.utils = ./default.nix;

  perSystem =
    { pkgs, ... }:
    {
      checks.utils-pbcopy = import ./checks/pbcopy.nix { inherit pkgs; };
    };
}
