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

  package = tooling.mkPackage { inherit scopes postProcess; };

  frontmatterTestResult =
    let
      frontmatterTests = import ./frontmatter-tests.nix;
    in
    if frontmatterTests.allPass then "pass" else throw "Frontmatter renderer tests failed";

  check = import ./checks.nix { inherit package pkgs frontmatterTestResult; };
in
{
  inherit (tooling)
    mkBlock
    mkInstructions
    mkAgent
    mkSkill
    ;

  blocks = scopes.claude.blocks;
  commands = scopes.claude.commands;
  skills = scopes.claude.skills;
  claude = instructions.claude;
  opencode = instructions.opencode;

  inherit package check;
}
