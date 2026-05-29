{ pkgs, lib }:

/*
  BOM package assembly tests — exercise the package/render surface contract for
  generated per-harness instruction bill-of-materials reports.
*/

let
  output = import ../output.nix { inherit pkgs lib; };

  scope = {
    harness = {
      name = "claude";
      outputDir = "claude";
    };
    instructions = {
      main = {
        embed = "# Final Root\n\nFinal rendered root body.";
        outputPath = "CLAUDE.md";
      };
      "commands/demo" = {
        embed = "---\ndescription: Demo\n---\nFinal rendered command body.";
        outputPath = "commands/demo.md";
      };
      "skills/demo/SKILL" = {
        embed = "---\nname: demo\ndescription: Demo skill\n---\nFinal rendered skill body.";
        outputPath = "skills/demo/SKILL.md";
      };
    };
    skillFiles = {
      "skills/demo/refs/example" = {
        embed = "Final rendered bundled reference body.";
        outputPath = "skills/demo/refs/example.md";
      };
    };
  };

  packageWithDefaults = output.mkPackage { scopes.claude = scope; };
  packageWithEncoding = output.mkPackage {
    scopes.claude = scope;
    bom.encoding = "cl100k_base";
  };
  packageWithVendoredPath = output.mkPackage {
    scopes.claude = scope;
    bom.encodingPath = "/tmp/cl100k_base.tiktoken";
  };
  defaultContents = map (entry: entry.content) packageWithDefaults.passthru.bom.entries.claude;

  authoredBomCollision = builtins.tryEval (
    (output.mkPackage {
      scopes.claude = scope // {
        instructions = scope.instructions // {
          authoredBom = {
            embed = "Authored BOM body";
            outputPath = "BOM.md";
          };
        };
      };
    }).drvPath
  );

  cases = [
    {
      name = "BOM default encoding is cl100k_base";
      pass = packageWithDefaults.passthru.bom.encoding == "cl100k_base";
      detail = "expected cl100k_base default encoding";
    }
    {
      name = "BOM encoding can be configured first-class";
      pass = packageWithEncoding.passthru.bom.encoding == "cl100k_base";
      detail = "expected explicit encoding to be surfaced in package metadata";
    }
    {
      name = "BOM path override does not change manifest entry collection";
      pass = builtins.length packageWithVendoredPath.passthru.bom.entries.claude == 4;
      detail = "expected vendored encoding path overrides to leave BOM manifest entries intact";
    }
    {
      name = "BOM manifest uses final rendered content";
      pass =
        (builtins.any (content: lib.hasInfix "Final rendered command body." content) defaultContents)
        && !(builtins.any (content: content == "Command body.") defaultContents);
      detail = "expected BOM manifest to contain processed rendered content, not authored fragments";
    }
    {
      name = "Skill subfiles are classified separately";
      pass = builtins.any (
        entry: entry.relativePath == "skills/demo/refs/example.md" && entry.category == "skillSubfiles"
      ) packageWithDefaults.passthru.bom.entries.claude;
      detail = "expected skill subfiles to be included in BOM entries";
    }
    {
      name = "Generated BOM is excluded from its own manifest";
      pass =
        !(builtins.any (
          entry: entry.relativePath == "BOM.md"
        ) packageWithDefaults.passthru.bom.entries.claude);
      detail = "expected BOM.md to be omitted from counted file entries";
    }
    {
      name = "Authored BOM.md collides with generated BOM";
      pass = !authoredBomCollision.success;
      detail = "expected generated BOM.md to reserve the harness-root destination";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
