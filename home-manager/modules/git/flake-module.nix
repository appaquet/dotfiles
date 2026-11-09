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
        jj-workspace-branch-unit = import ./checks/jj-workspace-branch-unit.nix {
          inherit pkgs;
          branchScript = ./scripts/jj-workspace-branch.sh;
          unitTest = ./checks/jj-workspace-branch-unit.sh;
        };
      };
    };
}
