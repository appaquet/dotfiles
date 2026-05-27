{ pkgs, lib }:

/*
  Duplicate block key detection tests — verifies that importBlocksTree throws
  when the same block name appears in multiple roots (e.g. global blocks/ and
  local agents/[agent]/blocks/).
*/

let
  files = import ../files.nix { inherit pkgs lib; };
  args = {
    scope = { };
  };

  dupBlocksDir = ./hierarchical-dup-blocks-data/blocks;
  dupBlocksAgentsDir = ./hierarchical-dup-blocks-data/agents;

  # ── Duplicate block keys across roots should throw ─────────────────────
  dupResult = builtins.tryEval (
    files.importBlocksTree {
      roots = [
        dupBlocksDir
        dupBlocksAgentsDir
      ];
      inherit args;
    }
  );
  dupThrows = !dupResult.success;

  # ── Single root should succeed ─────────────────────────────────────────
  singleResult = builtins.tryEval (
    files.importBlocksTree {
      roots = [ dupBlocksDir ];
      inherit args;
    }
  );
  singleSucceeds = singleResult.success;

  cases = [
    {
      name = "importBlocksTree throws on duplicate block keys across roots";
      pass = dupThrows;
      detail = "importBlocksTree should throw when same-name.nix exists in both global blocks/ and agents/some-agent/blocks/";
    }
    {
      name = "importBlocksTree succeeds with single root";
      pass = singleSucceeds;
      detail = "importBlocksTree should succeed when no duplicate block keys exist";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
