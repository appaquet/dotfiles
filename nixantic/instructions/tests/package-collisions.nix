{ pkgs, lib }:

/*
  Output package assembly tests — exercise the destination-uniqueness guard in
  output.nix mkPackage, which catches two files resolving to the same harness
  destination before symlinkJoin reports an opaque clash.
*/

let
  output = import ../output.nix { inherit pkgs lib; };

  mkScope =
    {
      instructions,
      skillFiles ? { },
    }:
    {
      harness.outputDir = "claude";
      inherit instructions skillFiles;
    };

  uniqueResult = builtins.tryEval (
    (output.mkPackage {
      scopes.claude = mkScope {
        instructions = {
          "skills/demo/SKILL" = {
            embed = "Skill main body";
            outputPath = "skills/demo/SKILL.md";
          };
        };
        skillFiles = {
          "skills/demo/refs/data" = {
            embed = "Bundled data";
            outputPath = "skills/demo/refs/data.md";
          };
        };
      };
    }).drvPath
  );

  collidingResult = builtins.tryEval (
    (output.mkPackage {
      scopes.claude = mkScope {
        instructions = {
          "skills/demo/SKILL" = {
            embed = "Skill main body";
            outputPath = "skills/demo/SKILL.md";
          };
        };
        skillFiles = {
          "skills/demo/SKILL" = {
            embed = "Sub-file colliding with the skill main file";
            outputPath = "skills/demo/SKILL.md";
          };
        };
      };
    }).drvPath
  );

  cases = [
    {
      name = "distinct destinations assemble";
      pass = uniqueResult.success;
      detail = "expected files with distinct destinations to assemble into a package";
    }
    {
      name = "duplicate destination fails before symlinkJoin";
      pass = !collidingResult.success;
      detail = "expected a sub-file colliding with a skill main file to fail with a destination collision";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
