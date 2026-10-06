{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        jj-promote-unit = import ./checks/jj-promote-unit.nix {
          inherit pkgs;
          promoteScript = ./scripts/jj-promote.sh;
          unitTest = ./checks/jj-promote-unit.sh;
        };
      };
    };
}
