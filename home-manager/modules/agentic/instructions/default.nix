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

  frontmatterTestResult =
    let
      frontmatterTests = import ./frontmatter-tests.nix;
    in
    if frontmatterTests.allPass then "pass" else throw "Frontmatter renderer tests failed";

  dualOutputTestResult =
    let
      dualOutputTests = import ./fixtures/dual-output-test.nix { inherit pkgs lib; };
    in
    if dualOutputTests.allPass then "pass" else throw "Dual-output pipeline tests failed";

  hierarchicalValidTestResult =
    let
      hierarchicalValidTests = import ./fixtures/hierarchical-valid.nix { inherit pkgs lib; };
    in
    if hierarchicalValidTests.allPass then "pass" else throw "Hierarchical valid import tests failed";

  hierarchicalDupAgentsTestResult =
    let
      hierarchicalDupAgentsTests = import ./fixtures/hierarchical-duplicate-agents.nix {
        inherit pkgs lib;
      };
    in
    if hierarchicalDupAgentsTests.allPass then
      "pass"
    else
      throw "Hierarchical duplicate agent tests failed";

  hierarchicalDupBlocksTestResult =
    let
      hierarchicalDupBlocksTests = import ./fixtures/hierarchical-duplicate-blocks.nix {
        inherit pkgs lib;
      };
    in
    if hierarchicalDupBlocksTests.allPass then
      "pass"
    else
      throw "Hierarchical duplicate block tests failed";

  hierarchicalDupCmdsTestResult =
    let
      hierarchicalDupCmdsTests = import ./fixtures/hierarchical-duplicate-commands.nix {
        inherit pkgs lib;
      };
    in
    if hierarchicalDupCmdsTests.allPass then
      "pass"
    else
      throw "Hierarchical duplicate command tests failed";

  check = import ./checks.nix {
    inherit
      package
      pkgs
      frontmatterTestResult
      dualOutputTestResult
      hierarchicalValidTestResult
      hierarchicalDupAgentsTestResult
      hierarchicalDupBlocksTestResult
      hierarchicalDupCmdsTestResult
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
