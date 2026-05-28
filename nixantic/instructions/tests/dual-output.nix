{ pkgs, lib }:

/*
  Dual-output pipeline tests — exercise the skill→command and authored×dual-output
  paths of scope.nix with synthetic inputs, covering cases that the production
  sources do not currently trigger (no real skill sets asCommand).

  Covers:
    - R24: a skill-derived command receives the pre-flight reference
      (injectCommandPreFlight applied in extraCommandsFromSkills).
    - R23.3: an authored instruction colliding with a dual-output entry is
      detected by the collisions list (fail-loud merge).
*/

let
  builders = import ../builders.nix { inherit pkgs lib; };
  harness = import ../harnesses/claude.nix { renderFrontmatter = builders.renderFrontmatter; };

  preFlightRef = "(See pre-flight)";

  # Minimal synthetic scope shared base. Each test overrides the raw* inputs it
  # needs; lib.fix wires the stage outputs the way makeScope does.
  baseSelf = {
    inherit harness;
    scopeApi = builders.scopeApi;
    blocks = {
      "pre-flight" = {
        reference = preFlightRef;
      };
    };
    rawCommands = { };
    rawSkills = { };
    rawAuthoredInstructions = { };
    agents = { };
    commands = { };
    skills = { };
  };

  mkScopeWith =
    overrides:
    lib.fix (
      self:
      (baseSelf // overrides { inherit self; })
      // builders.addDualOutput self
      // builders.addInstructions self
    );

  # ── Test: skill→command gets pre-flight injected ──────────────────────────
  skillWithCommand = {
    rawSkills = {
      mySkill = {
        kind = "directory";
        main = {
          description = "A skill that also emits a command";
          content = "Skill body content";
          asCommand = true;
        };
        files = { };
      };
    };
  };

  preflightScope = mkScopeWith (_: skillWithCommand);
  derivedCommand = preflightScope.extraCommandsFromSkills."commands/mySkill";
  preflightPresent = lib.hasInfix preFlightRef derivedCommand.embed;

  # ── Test: authored instruction colliding with dual-output entry ───────────
  collidingSources = {
    rawSkills = {
      ctxLoad = {
        kind = "directory";
        main = {
          name = "collide-cmd";
          description = "Skill emitting a command that collides with an authored file";
          content = "Skill body";
          asCommand = true;
        };
        files = { };
      };
    };
    rawAuthoredInstructions = {
      "commands/collide-cmd" = {
        heading = "Authored Collide";
        content = "Authored body that must not be silently overwritten";
      };
    };
  };

  collisionScope = mkScopeWith (_: collidingSources);
  collisionDetected = builtins.elem "commands/collide-cmd" collisionScope.collisions;

  cases = [
    {
      name = "skill-derived command receives pre-flight reference";
      pass = preflightPresent;
      detail = "expected pre-flight ref in extraCommandsFromSkills output";
    }
    {
      name = "authored vs dual-output command collision detected";
      pass = collisionDetected;
      detail = "expected commands/collide-cmd in collisions list";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
