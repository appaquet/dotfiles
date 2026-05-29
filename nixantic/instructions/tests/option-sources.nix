{ pkgs, lib }:

/*
  Source input renderer tests — exercise normalized source-set declarations
  without Home Manager evaluation. These tests keep lazy function application,
  dual outputs, skill subfiles, and expected failure modes close to scope.nix.
*/

let
  builders = import ../builders.nix { inherit pkgs lib; };
  sourcesLib = import ../../source-sets/lib.nix;
  harnesses = {
    claude = import ../harnesses/claude.nix { renderFrontmatter = builders.renderFrontmatter; };
    opencode = import ../harnesses/opencode.nix { renderFrontmatter = builders.renderFrontmatter; };
  };

  mkScope = args: builders.makeScope ({ harness = harnesses.claude; } // args);
  mkOpencodeScope = args: builders.makeScope ({ harness = harnesses.opencode; } // args);

  preFlightBlock = {
    heading = "Pre Flight";
    content = "Pre-flight option block";
  };

  optionBase = {
    blocks = {
      "pre-flight" = preFlightBlock;
    };
    agents = { };
    commands = { };
    skills = { };
    instructions = { };
  };

  optionBlockCommandScope = mkScope {
    sources = optionBase // {
      blocks = optionBase.blocks // {
        "shared-option" = {
          heading = "Shared Option";
          content = "Shared option block body";
        };
      };
      commands = {
        "use-option-block" =
          { scope }:
          {
            description = "Command referencing an option block";
            content = "Use ${scope.blocks."shared-option".reference}.";
          };
      };
    };
  };

  authoredClaudeScope = mkScope {
    sources = optionBase // {
      instructions = {
        "custom/only-claude" = {
          heading = "Only Claude";
          content = "Claude-specific option-authored instruction";
          outputPath = "special/only-claude.md";
          harnesses = [ "claude" ];
        };
      };
    };
  };

  authoredOpencodeScope = mkOpencodeScope {
    sources = optionBase // {
      instructions = {
        "custom/only-claude" = {
          heading = "Only Claude";
          content = "Claude-specific option-authored instruction";
          outputPath = "special/only-claude.md";
          harnesses = [ "claude" ];
        };
      };
    };
  };

  dualOutputScope = mkScope {
    sources = optionBase // {
      commands = {
        "option-dual-command" = {
          description = "Option command emitting a skill";
          content = "Command body";
          asSkill = true;
        };
      };
      skills = {
        "option-dual-skill" = {
          kind = "directory";
          main = {
            description = "Option skill emitting a command";
            content = "Skill body";
            asCommand = true;
          };
          files = { };
        };
      };
    };
  };

  skillFilesScope = mkScope {
    sources = optionBase // {
      skills = {
        "option-skill" = {
          kind = "directory";
          main = {
            description = "Option skill with bundled file";
            content = "Main option skill body";
          };
          files = {
            "references/sub.md" = {
              kind = "md";
              content = "Bundled markdown subfile";
            };
          };
        };
      };
    };
  };

  skillEntryFunctionScope = mkScope {
    sources = optionBase // {
      skills = {
        "function-skill" = {
          kind = "directory";
          main =
            { scope }:
            {
              description = "Option skill declared as a function";
              content = "Function skill uses ${scope.blocks."pre-flight".reference}.";
            };
          files = {
            "generated.md" = {
              kind = "nix";
              content = { scope }: "Generated file uses ${scope.blocks."pre-flight".reference}.";
            };
          };
        };
      };
    };
  };

  missingPreFlightResult = builtins.tryEval (
    (mkScope {
      sources = {
        blocks = { };
        agents = { };
        commands = {
          "needs-preflight" = {
            description = "Command missing pre-flight block";
            content = "Body";
          };
        };
        skills = { };
        instructions = { };
      };
    }).commands."needs-preflight".embed
  );

  missingDualPreFlightResult = builtins.tryEval (
    (mkScope {
      sources = {
        blocks = { };
        agents = { };
        commands = {
          "dual-needs-preflight" = {
            description = "Dual command missing pre-flight block";
            content = "Body";
            asSkill = true;
          };
        };
        skills = { };
        instructions = { };
      };
    }).extraSkillsFromCommands."skills/dual-needs-preflight/SKILL".embed
  );

  missingSkillMainResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        skills = {
          "malformed-skill" = {
            kind = "directory";
            description = "Missing main wrapper";
            content = "Body";
          };
        };
      };
    }).skills."malformed-skill".embed
  );

  unsupportedSkillEntryFunctionResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        skills = {
          "whole-entry-function" =
            { scope }:
            {
              main = {
                description = "Unsupported whole-entry function";
                content = "Body uses ${scope.blocks."pre-flight".reference}.";
              };
              files = { };
            };
        };
      };
    }).skills."whole-entry-function".embed
  );

  taggedContentWithoutTagResult = builtins.tryEval (
    (builders.mkBlock {
      content = "Plain content";
      taggedContent = "Tagged content";
    }).embed
  );

  sourceDeclarationsNormalized = builders.normalizeSourceDeclarations {
    workflow = {
      blocks = {
        "source-set-block" = {
          heading = "Source Set Block";
          content = "Source-set block body";
        };
      };
      commands = {
        "source-set-command" =
          { scope }:
          {
            description = "Command referencing a source-set block";
            content = "Use ${scope.blocks."source-set-block".reference}.";
            noInjectPreFlight = true;
          };
      };
      agents = { };
      skills = { };
      instructions = { };
    };

    docs = {
      blocks = { };
      agents = { };
      commands = {
        "cross-source-set-command" =
          { scope }:
          {
            description = "Command referencing another source set";
            content = "Use ${scope.blocks."source-set-block".reference}.";
            noInjectPreFlight = true;
          };
      };
      skills = { };
      instructions = { };
    };
  };

  sourceScope = mkScope {
    sources = sourceDeclarationsNormalized.sources;
  };

  duplicateSourceResult = builtins.tryEval (
    sourcesLib.resolveSources {
      sources = {
        owner-a = {
          blocks.duplicate = {
            heading = "Duplicate A";
            content = "A";
          };
        };
        owner-b = {
          blocks.duplicate = {
            heading = "Duplicate B";
            content = "B";
          };
        };
      };
    }
  );

  selfReferenceResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          self =
            { scope }:
            {
              description = "Self-referential command";
              content = scope.commands.self.embed;
            };
        };
      };
    }).commands.self.embed
  );

  cases = [
    {
      name = "option block referenced by option command";
      pass =
        lib.hasInfix "(See: Shared Option)" optionBlockCommandScope.commands."use-option-block".embed
        && lib.hasInfix "(See: Pre Flight)" optionBlockCommandScope.commands."use-option-block".embed;
      detail = "expected option block and pre-flight references in command output";
    }
    {
      name = "option authored instruction outputPath and harness filtering";
      pass =
        authoredClaudeScope.instructions."custom/only-claude".outputPath == "special/only-claude.md"
        && !(builtins.hasAttr "custom/only-claude" authoredOpencodeScope.instructions);
      detail = "expected custom outputPath for Claude and no opencode instruction";
    }
    {
      name = "option command dual-output asSkill";
      pass = builtins.hasAttr "skills/option-dual-command/SKILL" dualOutputScope.instructions;
      detail = "expected command-derived skill output";
    }
    {
      name = "option skill-derived command asCommand";
      pass = builtins.hasAttr "commands/option-dual-skill" dualOutputScope.instructions;
      detail = "expected skill-derived command output";
    }
    {
      name = "option skill main plus bundled subfile";
      pass =
        builtins.hasAttr "option-skill" skillFilesScope.skills
        &&
          skillFilesScope.skillFiles."skills/option-skill/references/sub.md".embed
          == "Bundled markdown subfile";
      detail = "expected option skill and bundled markdown file";
    }
    {
      name = "option skill whole entry function";
      pass =
        lib.hasInfix "(See: Pre Flight)" skillEntryFunctionScope.skills."function-skill".embed
        &&
          skillEntryFunctionScope.skillFiles."skills/function-skill/generated.md".embed
          == "Generated file uses (See: Pre Flight).";
      detail = "expected skill main and nix subfile functions to receive scope";
    }
    {
      name = "command pre-flight injection fails clearly when block is missing";
      pass = !missingPreFlightResult.success;
      detail = "expected missing pre-flight block to fail during command injection";
    }
    {
      name = "dual command pre-flight injection fails clearly when block is missing";
      pass = !missingDualPreFlightResult.success;
      detail = "expected missing pre-flight block to fail during command-derived skill injection";
    }
    {
      name = "malformed skill missing main fails";
      pass = !missingSkillMainResult.success;
      detail = "expected skill entries without main to fail before constructor use";
    }
    {
      name = "skill whole entry functions are unsupported";
      pass = !unsupportedSkillEntryFunctionResult.success;
      detail = "expected skill source application to target main, not the whole entry";
    }
    {
      name = "taggedContent requires tag";
      pass = !taggedContentWithoutTagResult.success;
      detail = "expected mkBlock to reject taggedContent without tag";
    }
    {
      name = "source sets flatten without owner scope paths";
      pass =
        lib.hasInfix "(See: Source Set Block)" sourceScope.commands."source-set-command".embed
        && lib.hasInfix "(See: Source Set Block)" sourceScope.commands."cross-source-set-command".embed;
      detail = "expected source-set commands to reference flat scope.blocks keys across owners";
    }
    {
      name = "duplicate source-set artifact fails";
      pass = !duplicateSourceResult.success;
      detail = "expected duplicate source-set keys to fail during normalization";
    }
    {
      name = "self-referential option source fails";
      pass = !selfReferenceResult.success;
      detail = "expected self-referential command evaluation failure";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
