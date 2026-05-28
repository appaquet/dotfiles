{
  pkgs,
  lib,
  postProcess ? false,
  sourceRoots ? [ ],
  sources ? { },
}:

let
  tooling = import ./builders.nix { inherit pkgs lib; };
  sourceSets = import ../source-sets/lib.nix;
  harnesses = {
    claude = import ./harnesses/claude.nix { renderFrontmatter = tooling.renderFrontmatter; };
    opencode = import ./harnesses/opencode.nix { renderFrontmatter = tooling.renderFrontmatter; };
  };

  resolvedSources = sourceSets.resolveSources { inherit sourceRoots sources; };
  normalizedSources = tooling.normalizeSourceDeclarations resolvedSources;

  scopes = lib.mapAttrs (
    _: harness:
    tooling.makeScope {
      inherit harness;
      sources = normalizedSources.sources;
    }
  ) harnesses;
  instructions = lib.mapAttrs (_: scope: scope.instructions) scopes;
  blocks = lib.mapAttrs (_: scope: scope.blocks) scopes;

  package = tooling.mkPackage { inherit scopes postProcess; };

  testResult =
    let
      tests = import ./tests { inherit pkgs lib; };
    in
    if tests.allPass then "pass" else throw "Nixantic instruction tests failed";

  check = import ./checks.nix {
    inherit
      package
      pkgs
      testResult
      ;
  };
in
{
  inherit
    package
    check
    blocks
    ;

  # Rendered instructions for each harness
  claude = instructions.claude;
  opencode = instructions.opencode;
}
