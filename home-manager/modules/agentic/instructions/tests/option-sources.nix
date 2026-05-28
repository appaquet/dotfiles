{ pkgs, lib }:

/*
  Option-source renderer tests — exercise decentralized raw source declarations
  without Home Manager evaluation. These tests keep provider selection, lazy
  function application, dual outputs, skill subfiles, and expected failure modes
  close to scope.nix.
*/

let
  builders = import ../builders.nix { inherit pkgs lib; };
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
    sourceMode = "options";
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

  mixedCommandScope = mkScope {
    sourceMode = "mixed";
    sources = {
      commands = {
        "mixed-directory-block" =
          { scope }:
          {
            description = "Command referencing a directory block";
            content = "Use ${scope.blocks."deep-thinking".reference}.";
            noInjectPreFlight = true;
          };
      };
    };
  };

  authoredClaudeScope = mkScope {
    sourceMode = "options";
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
    sourceMode = "options";
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
    sourceMode = "options";
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
    sourceMode = "options";
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
    sourceMode = "options";
    sources = optionBase // {
      skills = {
        "function-skill" =
          { scope }:
          {
            kind = "directory";
            main = {
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

  sourceSetNormalized = builders.normalizeSourceSets {
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

  sourceSetScope = mkScope {
    sourceMode = "options";
    sources = sourceSetNormalized.sources;
    sourceProvenance = sourceSetNormalized.provenance;
  };

  duplicateResult = builtins.tryEval (
    (mkScope {
      sourceMode = "mixed";
      sources = {
        blocks = {
          "pre-flight" = {
            heading = "Duplicate Pre Flight";
            content = "Duplicate";
          };
        };
      };
    }).rawBlocks
  );

  duplicateSourceSetResult = builtins.tryEval (
    (builders.normalizeSourceSets {
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
    }).sources.blocks
  );

  duplicateMixedSourceSetNormalized = builders.normalizeSourceSets {
    owner-a = {
      blocks."pre-flight" = {
        heading = "Duplicate Pre Flight";
        content = "Duplicate";
      };
    };
  };

  duplicateMixedSourceSetResult = builtins.tryEval (
    (mkScope {
      sourceMode = "mixed";
      sources = duplicateMixedSourceSetNormalized.sources;
      sourceProvenance = duplicateMixedSourceSetNormalized.provenance;
    }).rawBlocks
  );

  duplicateNormalizedProviderResult = builtins.tryEval (
    (builders.mergeSourceProviders {
      leftSources = {
        blocks.duplicate = {
          heading = "Duplicate Option";
          content = "Option";
        };
      };
      rightSources = duplicateSourceSetNormalized.sources;
      rightProvenance = duplicateSourceSetNormalized.provenance;
    }).sources.blocks
  );

  duplicateSourceSetNormalized = builders.normalizeSourceSets {
    owner-a = {
      blocks.duplicate = {
        heading = "Duplicate Source Set";
        content = "Source set";
      };
    };
  };

  selfReferenceResult = builtins.tryEval (
    (mkScope {
      sourceMode = "options";
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
      name = "mixed additive option command references directory block";
      pass = lib.hasInfix "<deep-thinking>" mixedCommandScope.commands."mixed-directory-block".embed;
      detail = "expected small additive option source to combine with directory sources in mixed mode";
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
      detail = "expected whole skill entry and nix subfile functions to receive scope";
    }
    {
      name = "source sets flatten without owner scope paths";
      pass =
        lib.hasInfix "(See: Source Set Block)" sourceSetScope.commands."source-set-command".embed
        && lib.hasInfix "(See: Source Set Block)" sourceSetScope.commands."cross-source-set-command".embed;
      detail = "expected source-set commands to reference flat scope.blocks keys across owners";
    }
    {
      name = "duplicate source-set artifact fails";
      pass = !duplicateSourceSetResult.success;
      detail = "expected duplicate source-set keys to fail during normalization";
    }
    {
      name = "duplicate directory and source-set artifact fails";
      pass = !duplicateMixedSourceSetResult.success;
      detail = "expected mixed directory/source-set duplicate to fail with provenance";
    }
    {
      name = "duplicate normalized providers fail";
      pass = !duplicateNormalizedProviderResult.success;
      detail = "expected duplicate option/source-set keys to fail before renderer input assembly";
    }
    {
      name = "duplicate directory and option source fails";
      pass = !duplicateResult.success;
      detail = "expected duplicate pre-flight block failure in mixed mode";
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
