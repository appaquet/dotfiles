{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks =
        let
          jjUtils = import ./jj-utils.nix { inherit pkgs; };
        in
        {
          jj-promote-unit = import ./checks/jj-promote-unit.nix {
            inherit pkgs jjUtils;
            unitTest = ./checks/jj-promote-unit.sh;
          };
          jj-workspace-branch-unit = import ./checks/jj-workspace-branch-unit.nix {
            inherit pkgs jjUtils;
            unitTest = ./checks/jj-workspace-branch-unit.sh;
          };
          jj-stack-unit = import ./checks/jj-stack-unit.nix {
            inherit pkgs jjUtils;
            unitTest = ./checks/jj-stack-unit.sh;
          };
          jj-workspace-utils-unit = import ./checks/jj-workspace-utils-unit.nix {
            inherit pkgs jjUtils;
            unitTest = ./checks/jj-workspace-utils-unit.sh;
          };
        };
    };
}
