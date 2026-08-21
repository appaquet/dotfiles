{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  output = import ../output.nix { inherit pkgs lib; };
  harness = (import ../harnesses { renderFrontmatter = builders.renderFrontmatter; }).claude;
  opencodeHarness =
    (import ../harnesses { renderFrontmatter = builders.renderFrontmatter; }).opencode;
  mergeSettings.harnesses.claude.rules.output = "merge-main";

  mkScope = sources: settings: builders.makeScope { inherit harness sources settings; };
  mkOpencodeScope =
    sources: settings:
    builders.makeScope {
      harness = opencodeHarness;
      inherit sources settings;
    };
  sources = {
    instructions = {
      main = {
        role = "main";
        heading = "Main";
        content = "Main body";
      };
      zebra = {
        role = "rule";
        heading = "Zebra";
        content = "Z rule";
      };
      alpha = {
        role = "rule";
        heading = "Alpha";
        content = "A rule";
      };
      hidden = {
        role = "rule";
        harnesses = [ "opencode" ];
        heading = "Hidden";
        content = "Hidden rule";
      };
      regular = {
        heading = "Regular";
        content = "Regular body";
      };
    };
  };
  filesScope = mkScope (
    sources
    // {
      instructions = sources.instructions // {
        alpha.outputPath = "custom/alpha.md";
      };
    }
  ) { };
  opencodeFilesScope = mkOpencodeScope (
    sources
    // {
      instructions = sources.instructions // {
        alpha.outputPath = "custom/alpha.md";
      };
    }
  ) { };
  mergedScope = mkScope sources mergeSettings;
  emptyScope = mkScope { } mergeSettings;
  missingMain = builtins.tryEval (
    (mkScope {
      instructions.only-rule = {
        role = "rule";
        heading = "Rule";
        content = "Rule body";
      };
    } mergeSettings).instructions
  );
  multipleMains = builtins.tryEval (
    (mkScope {
      instructions = {
        one = {
          role = "main";
          heading = "One";
          content = "One";
        };
        two = {
          role = "main";
          heading = "Two";
          content = "Two";
        };
        rule = {
          role = "rule";
          heading = "Rule";
          content = "Rule";
        };
      };
    } mergeSettings).instructions
  );
  collision = builtins.tryEval (
    (output.mkPackage {
      scopes.claude = mkScope {
        instructions.regular = {
          heading = "Regular";
          content = "Regular";
          outputPath = "commands/shared.md";
        };
        commands.shared = {
          description = "Shared";
          content = "Command";
        };
      } { };
    }).drvPath
  );
  postProcessed = output.mkPackage {
    scopes.claude = mkScope {
      instructions = {
        main = {
          role = "main";
          heading = "Main";
          content = "Main.";
        };
        rule = {
          role = "rule";
          heading = "Rule";
          content = "Rule..";
        };
      };
    } mergeSettings;
    postProcess = true;
  };
  postProcessedContent = builtins.head postProcessed.passthru.bom.entries.claude;
  unknownHarnessSettings = builtins.tryEval (
    (import ../default.nix {
      inherit pkgs lib;
      settings.harnesses.unknown.rules.output = "files";
    }).package.drvPath
  );
  invalidRuleOutput = builtins.tryEval (
    (import ../default.nix {
      inherit pkgs lib;
      settings.harnesses.claude.rules.output = "invalid";
    }).package.drvPath
  );
  invalidRole = builtins.tryEval (
    (mkScope {
      instructions.invalid = {
        role = "other";
        heading = "Invalid";
        content = "Invalid";
      };
    } { }).instructions.invalid.embed
  );

  cases = [
    {
      name = "files emits each rule and preserves authored output paths";
      pass =
        filesScope.instructions.alpha.outputPath == "custom/alpha.md"
        && builtins.hasAttr "zebra" filesScope.instructions;
      detail = "expected files mode to keep standalone rule artifacts and overrides";
    }
    {
      name = "instruction roles select main and standalone rule paths";
      pass =
        filesScope.instructions.main.outputPath == "CLAUDE.md"
        && filesScope.instructions.zebra.outputPath == "rules/zebra.md"
        && filesScope.instructions.regular.outputPath == "regular.md"
        && opencodeFilesScope.instructions.main.outputPath == "AGENTS.md"
        && opencodeFilesScope.instructions.zebra.outputPath == "rules/zebra.md";
      detail = "expected role-derived paths without relying on instruction key prefixes";
    }
    {
      name = "merge-main filters inactive rules, sorts active keys, and omits standalone artifacts";
      pass =
        mergedScope.instructions.main.embed == "# Main\n\nMain body\n\nA rule\n\nZ rule"
        && !(builtins.hasAttr "alpha" mergedScope.instructions)
        && !(builtins.hasAttr "zebra" mergedScope.instructions)
        && !(builtins.hasAttr "hidden" mergedScope.instructions);
      detail = "expected active lexical alpha then zebra bodies in main only";
    }
    {
      name = "merge-main accepts an empty profile";
      pass = emptyScope.instructions == { };
      detail = "expected no instructions to remain a valid rendered profile";
    }
    {
      name = "merge-main requires exactly one main when active rules exist";
      pass = !missingMain.success && !multipleMains.success;
      detail = "expected missing and multiple main declarations to fail";
    }
    {
      name = "renderer-selected logical paths still participate in destination collisions";
      pass = !collision.success;
      detail = "expected an instruction override and command to collide at commands/shared.md";
    }
    {
      name = "merged content is post-processed exactly once";
      pass = postProcessedContent.content == "# Main\nMain\nRule.";
      detail = "expected Rule.. to retain one trailing dot after one post-processing pass";
    }
    {
      name = "framework validates configured harnesses and rule output values";
      pass = !unknownHarnessSettings.success && !invalidRuleOutput.success && !invalidRole.success;
      detail = "expected unknown harness keys, invalid output values, and invalid roles to fail";
    }
  ];
  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
