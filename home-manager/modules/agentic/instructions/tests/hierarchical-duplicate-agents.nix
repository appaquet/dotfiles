{ pkgs, lib }:

/*
  Duplicate agent stem detection tests — verifies that importFlatTree throws
  a descriptive error when two .nix files in different subdirectories share
  the same filename stem.
*/

let
  files = import ../files.nix { inherit pkgs lib; };
  args = {
    scope = { };
  };

  dupAgentsDir = ./fixtures/hierarchical-dup-agents-data/agents;
  validAgentsDir = ./fixtures/hierarchical-valid-data/agents;

  # ── Duplicate stems should throw ───────────────────────────────────────
  dupResult = builtins.tryEval (
    files.importFlatTree {
      dir = dupAgentsDir;
      inherit args;
    }
  );
  dupThrows = !dupResult.success;

  # ── No duplicates should succeed ───────────────────────────────────────
  noDupResult = builtins.tryEval (
    files.importFlatTree {
      dir = validAgentsDir;
      inherit args;
    }
  );
  noDupSucceeds = noDupResult.success;

  cases = [
    {
      name = "importFlatTree throws on duplicate agent stems";
      pass = dupThrows;
      detail = "importFlatTree should throw when code-style.nix exists in both foo/ and bar/";
    }
    {
      name = "importFlatTree succeeds when no duplicate stems";
      pass = noDupSucceeds;
      detail = "importFlatTree should succeed on valid nested directories without duplicates";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
