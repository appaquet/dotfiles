{
  pkgs,
  lib,
  postProcess ? false,
  bom ? { },
  sourceRoots ? [ ],
  sources ? { },
  settings ? { },
}:

let
  defaultSettings = {
    versionControl.mode = "jj";
  };
  effectiveSettings = lib.recursiveUpdate defaultSettings settings;
  instructionApi = import ./builders.nix { inherit pkgs lib; };
  sourceSets = import ../source-sets.nix;
  harnesses = import ./harnesses {
    renderFrontmatter = instructionApi.renderFrontmatter;
  };
  harnessNames = builtins.attrNames harnesses;

  ownerIndexedSources = sourceSets.resolveSources { inherit sourceRoots sources; };
  flattenedSources = instructionApi.normalizeSourceDeclarations ownerIndexedSources;

  scopes = lib.mapAttrs (
    _: harness:
    instructionApi.makeScope {
      inherit harness;
      sources = flattenedSources.sources;
      settings = effectiveSettings;
    }
  ) harnesses;
  instructions = lib.mapAttrs (_: scope: scope.instructions) scopes;
  blocks = lib.mapAttrs (_: scope: scope.blocks) scopes;

  package = instructionApi.mkPackage { inherit scopes postProcess bom; };

  testResult =
    let
      tests = import ./tests { inherit pkgs lib; };
    in
    if tests.allPass then "pass" else throw "Nixantic instruction tests failed";

  check = import ./checks.nix {
    inherit
      package
      pkgs
      lib
      testResult
      ;
  };
in
{
  inherit
    package
    check
    blocks
    harnessNames
    harnesses
    ;
}
// instructions
// {
  harnesses = harnesses;
}
