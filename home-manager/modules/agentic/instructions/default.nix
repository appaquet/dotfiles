{
  pkgs,
  lib,
  postProcess ? false,
}:

let
  tooling = import ./builders.nix { inherit pkgs lib; };
  harnesses = {
    claude = import ./harnesses/claude.nix { renderFrontmatter = tooling.renderFrontmatter; };
    opencode = import ./harnesses/opencode.nix { renderFrontmatter = tooling.renderFrontmatter; };
  };

  scopes = lib.mapAttrs (_: harness: tooling.makeScope harness) harnesses;
  instructions = lib.mapAttrs (_: scope: scope.instructions) scopes;
  blocks = lib.mapAttrs (_: scope: scope.blocks) scopes;

  package = tooling.mkPackage { inherit scopes postProcess; };

  testResult =
    let
      tests = import ./tests { inherit pkgs lib; };
    in
    if tests.allPass then "pass" else throw "Agentic instruction tests failed";

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
