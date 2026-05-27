{ pkgs, lib }:

/*
  Valid hierarchical import tests — exercise importFlatTree and importBlocksTree
  with nested directory structures. Covers:

    - importFlatTree returns flat keys (no / in key names) for nested agents
    - importBlocksTree discovers blocks from multiple roots (global + local blocks/)
    - importFlatTree succeeds when no duplicate stems exist
*/

let
  files = import ../files.nix { inherit pkgs lib; };
  args = {
    scope = { };
  };

  validAgentsDir = ./hierarchical-valid-data/agents;
  validBlocksDir = ./hierarchical-valid-data/blocks;
  dupAgentsDir = ./hierarchical-dup-agents-data/agents;
  dupBlocksDir = ./hierarchical-dup-blocks-data/blocks;
  dupBlocksAgentsDir = ./hierarchical-dup-blocks-data/agents;

  # ── importFlatTree with nested agents: flat keys, no / ──────────────────
  flatTreeResult = builtins.tryEval (
    files.importFlatTree {
      dir = validAgentsDir;
      inherit args;
    }
  );
  flatTreeSucceeds = flatTreeResult.success;
  flatTreeKeysFlat =
    if flatTreeResult.success then
      builtins.all (k: builtins.match ".*/.*" k == null) (builtins.attrNames flatTreeResult.value)
    else
      false;
  flatTreeHasKeys =
    if flatTreeResult.success then
      flatTreeResult.value ? "code-style" && flatTreeResult.value ? "branch-diff"
    else
      false;

  # ── importBlocksTree discovers from multiple roots ──────────────────────
  blocksResult = builtins.tryEval (
    files.importBlocksTree {
      roots = [
        validBlocksDir
        validAgentsDir
      ];
      inherit args;
    }
  );
  blocksSucceeds = blocksResult.success;
  blocksFromBothRoots =
    if blocksResult.success then
      blocksResult.value ? "test-block" && blocksResult.value ? "local-block"
    else
      false;

  # ── No-duplicate agents case succeeds ───────────────────────────────────
  noDupResult = builtins.tryEval (
    files.importFlatTree {
      dir = validAgentsDir;
      inherit args;
    }
  );
  noDupSucceeds = noDupResult.success;

  # ── Test cases ──────────────────────────────────────────────────────────
  cases = [
    {
      name = "importFlatTree succeeds on nested agent hierarchy";
      pass = flatTreeSucceeds;
      detail = "importFlatTree should succeed on valid nested directory";
    }
    {
      name = "importFlatTree returns flat keys only";
      pass = flatTreeKeysFlat;
      detail = "all keys should be filename stems without /";
    }
    {
      name = "importFlatTree discovers all nested agents";
      pass = flatTreeHasKeys;
      detail = "should find code-style and branch-diff agents";
    }
    {
      name = "importBlocksTree discovers blocks from multiple roots";
      pass = blocksSucceeds && blocksFromBothRoots;
      detail = "should find test-block from global blocks/ and local-block from agents/reviewers/blocks/";
    }
    {
      name = "no-duplicate agents import succeeds";
      pass = noDupSucceeds;
      detail = "importFlatTree should succeed when no duplicate stems exist";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
