{ pkgs, lib }:

/*
  Duplicate command key detection tests — verifies that importFlatTree throws
  a descriptive error when two command .nix files in different subdirectories
  share the same filename stem. Uses the same importFlatTree as agents.
*/

let
  files = import ../files.nix { inherit pkgs lib; };
  args = {
    scope = { };
  };

  dupCmdsDir = ./fixtures/hierarchical-dup-cmds-data/commands;

  dupResult = builtins.tryEval (
    files.importFlatTree {
      dir = dupCmdsDir;
      inherit args;
    }
  );
  dupThrows = !dupResult.success;

  cases = [
    {
      name = "importFlatTree throws on duplicate command stems";
      pass = dupThrows;
      detail = "importFlatTree should throw when proj-init.nix exists in both group-a/ and group-b/";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
