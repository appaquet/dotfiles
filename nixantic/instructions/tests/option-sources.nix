{ pkgs, lib }:

/*
  Source input renderer tests — exercise normalized source-set declarations
  without Home Manager evaluation. These tests keep lazy function application,
  dual outputs, skill subfiles, and expected failure modes close to scope.nix.
*/

let
  builders = import ../builders.nix { inherit pkgs lib; };
  sourcesLib = import ../../source-sets.nix;
  harnesses = import ../harnesses { renderFrontmatter = builders.renderFrontmatter; };

  mkScope = args: builders.makeScope ({ harness = harnesses.claude; } // args);
  mkOpencodeScope = args: builders.makeScope ({ harness = harnesses.opencode; } // args);

  preFlightBlock = {
    heading = "Pre Flight";
    content = "Pre-flight option block";
    injectReferenceIntoCommands = true;
  };

  taskManagementBlock = {
    heading = "Task Management";
    content = "Task-management option block";
    injectReferenceIntoCommands = true;
  };

  additionalDefaultBlock = {
    heading = "Additional Default";
    content = "Additional default option block";
    injectReferenceIntoCommands = true;
  };

  optionBase = {
    blocks = {
      "pre-flight" = preFlightBlock;
      "task-management" = taskManagementBlock;
      "additional-default" = additionalDefaultBlock;
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

  commandReferenceScope = mkScope {
    sources = optionBase // {
      commands = {
        target = {
          description = "Target command";
          content = "Target body";
        };
        renamed = {
          name = "custom-target";
          description = "Renamed target command";
          content = "Renamed body";
        };
        "uses-command" =
          { scope }:
          {
            description = "Command referencing commands";
            content = "Use ${scope.commands.target.reference} or ${scope.commands.renamed.reference}.";
          };
      };
    };
  };

  skillReferenceScope = mkScope {
    sources = optionBase // {
      commands = {
        "skill-command" = {
          description = "Command emitting a skill";
          content = "Command body";
          asSkill = true;
        };
        "renamed-skill-command" = {
          name = "custom-skill-command";
          description = "Renamed command emitting a skill";
          content = "Renamed command body";
          asSkill = true;
        };
        "uses-skills" =
          { scope }:
          {
            description = "Command referencing skills";
            content = "Use ${scope.skills."directory-skill".reference}, ${
              scope.skills."skill-command".reference
            }, and ${scope.skills."custom-skill-command".name}.";
          };
      };
      skills = {
        "directory-skill" = {
          kind = "directory";
          main = {
            description = "Directory skill";
            content = "Skill body";
          };
          files = { };
        };
      };
    };
  };

  agentReferenceScope = mkScope {
    sources = optionBase // {
      agents = {
        target = {
          description = "Target agent description";
          content = "Target agent body";
        };
        renamed = {
          name = "custom-agent";
          description = "Renamed agent description";
          content = "Renamed agent body";
        };
      };
      commands = {
        "uses-agents" =
          { scope }:
          {
            description = "Command referencing agents";
            content = "Use ${scope.agents.target.name}: ${scope.agents.target.description}; ${scope.agents.renamed.reference}.";
          };
      };
    };
  };

  missingAgentReferenceResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          "uses-missing-agent" =
            { scope }:
            {
              description = "Command referencing a missing agent";
              content = "Use ${
                (scope.agents.missing or (throw "missing agent reference unavailable")).reference
              }.";
            };
        };
      };
    }).commands."uses-missing-agent".embed
  );

  unsupportedAgentReferenceFieldResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        agents = {
          target = {
            description = "Target agent description";
            content = "Target agent body";
          };
        };
        commands = {
          "uses-unsupported-agent-field" =
            { scope }:
            {
              description = "Command referencing unsupported agent data";
              content = "Use ${scope.agents.target.embed or (throw "processed agent content unavailable")}.";
            };
        };
      };
    }).commands."uses-unsupported-agent-field".embed
  );

  missingSkillReferenceResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          "uses-missing-skill" =
            { scope }:
            {
              description = "Command referencing a missing skill";
              content = "Use ${
                (scope.skills.missing or (throw "missing skill reference unavailable")).reference
              }.";
            };
        };
      };
    }).commands."uses-missing-skill".embed
  );

  unsupportedSkillReferenceFieldResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          "directory-skill" = {
            description = "Unrelated command";
            content = "Command body";
          };
          "uses-unsupported-skill-field" =
            { scope }:
            {
              description = "Command referencing unsupported skill data";
              content = "Use ${
                scope.skills."directory-skill".embed or (throw "processed skill content unavailable")
              }.";
            };
        };
        skills = {
          "directory-skill" = {
            kind = "directory";
            main = {
              description = "Directory skill";
              content = "Skill body";
            };
            files = { };
          };
        };
      };
    }).commands."uses-unsupported-skill-field".embed
  );

  missingCommandReferenceResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          "uses-missing" =
            { scope }:
            {
              description = "Command referencing a missing command";
              content = "Use ${
                (scope.commands.missing or (throw "missing command reference unavailable")).reference
              }.";
            };
        };
      };
    }).commands."uses-missing".embed
  );

  unsupportedCommandReferenceFieldResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          target = {
            description = "Target command";
            content = "Target body";
          };
          "uses-unsupported-field" =
            { scope }:
            {
              description = "Command referencing unsupported command data";
              content = "Use ${scope.commands.target.embed or (throw "processed command content unavailable")}.";
            };
        };
      };
    }).commands."uses-unsupported-field".embed
  );

  onlyInjectBlockReferencesScope = mkScope {
    sources = optionBase // {
      commands = {
        "ordered-references" = {
          description = "Command replacing default block references";
          content = "Ordered body";
          onlyInjectBlockReferences = [
            "pre-flight"
            "task-management"
          ];
        };
        "empty-references" = {
          description = "Command injecting no block references";
          content = "Empty body";
          onlyInjectBlockReferences = [ ];
        };
      };
    };
  };

  duplicateOnlyInjectBlockReferencesResult = builtins.tryEval (
    (mkScope {
      sources = optionBase // {
        commands = {
          duplicate = {
            description = "Command with duplicate replacement references";
            content = "Duplicate body";
            onlyInjectBlockReferences = [
              "pre-flight"
              "pre-flight"
            ];
          };
        };
      };
    }).commands.duplicate.embed
  );

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

  missingBoilerplateScope = (
    mkScope {
      sources = {
        blocks = { };
        agents = { };
        commands = {
          "needs-preflight" = {
            description = "Command without boilerplate block";
            content = "Body";
          };
        };
        skills = { };
        instructions = { };
      };
    }
  );

  missingDualBoilerplateScope = (
    mkScope {
      sources = {
        blocks = { };
        agents = { };
        commands = {
          "dual-needs-preflight" = {
            description = "Dual command without boilerplate block";
            content = "Body";
            asSkill = true;
          };
        };
        skills = { };
        instructions = { };
      };
    }
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
            onlyInjectBlockReferences = [ ];
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
            onlyInjectBlockReferences = [ ];
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
              content = scope.commands.self.embed or (throw "processed command content unavailable");
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
      detail = "expected option block and default injected references in command output";
    }
    {
      name = "raw command references expose name and reference";
      pass =
        lib.hasInfix "Use (See command: target) or (See command: custom-target)."
          commandReferenceScope.commands."uses-command".embed
        && commandReferenceScope.commands."uses-command".reference == "(See command: uses-command)";
      detail = "expected command source functions to reference raw command metadata";
    }
    {
      name = "raw skill references expose name and reference";
      pass =
        lib.hasInfix
          "Use (See skill: directory-skill), (See skill: skill-command), and custom-skill-command."
          skillReferenceScope.commands."uses-skills".embed
        && skillReferenceScope.skills."directory-skill".reference == "(See skill: directory-skill)";
      detail = "expected source functions to reference raw directory and command-derived skill metadata";
    }
    {
      name = "raw agent references expose name description and reference";
      pass =
        lib.hasInfix "Use target: Target agent description; (See agent: custom-agent)."
          agentReferenceScope.commands."uses-agents".embed
        && agentReferenceScope.agents.target.reference == "(See agent: target)";
      detail = "expected source functions to reference raw agent metadata";
    }
    {
      name = "missing raw agent reference fails";
      pass = !missingAgentReferenceResult.success;
      detail = "expected missing scope.agents entry to fail during evaluation";
    }
    {
      name = "unsupported raw agent reference field fails";
      pass = !unsupportedAgentReferenceFieldResult.success;
      detail = "expected unsupported scope.agents field access to fail during evaluation";
    }
    {
      name = "missing raw skill reference fails";
      pass = !missingSkillReferenceResult.success;
      detail = "expected missing scope.skills entry to fail during evaluation";
    }
    {
      name = "unsupported raw skill reference field fails";
      pass = !unsupportedSkillReferenceFieldResult.success;
      detail = "expected unsupported scope.skills field access to fail during evaluation";
    }
    {
      name = "missing raw command reference fails";
      pass = !missingCommandReferenceResult.success;
      detail = "expected missing scope.commands entry to fail during evaluation";
    }
    {
      name = "unsupported raw command reference field fails";
      pass = !unsupportedCommandReferenceFieldResult.success;
      detail = "expected unsupported scope.commands field access to fail during evaluation";
    }
    {
      name = "command replacement references preserve authored order";
      pass =
        lib.hasInfix "Ordered body\n\n(See: Pre Flight)\n\n(See: Task Management)"
          onlyInjectBlockReferencesScope.commands."ordered-references".embed
        && !(lib.hasInfix "(See: Additional Default)"
          onlyInjectBlockReferencesScope.commands."ordered-references".embed
        );
      detail = "expected onlyInjectBlockReferences to inject exactly pre-flight then task-management";
    }
    {
      name = "empty command replacement references inject nothing";
      pass =
        lib.hasInfix "Empty body" onlyInjectBlockReferencesScope.commands."empty-references".embed
        && !(lib.hasInfix "(See: Pre Flight)"
          onlyInjectBlockReferencesScope.commands."empty-references".embed
        )
        && !(lib.hasInfix "(See: Task Management)"
          onlyInjectBlockReferencesScope.commands."empty-references".embed
        )
        && !(lib.hasInfix "(See: Additional Default)"
          onlyInjectBlockReferencesScope.commands."empty-references".embed
        );
      detail = "expected onlyInjectBlockReferences = [ ] to suppress all injected references";
    }
    {
      name = "duplicate command replacement references fail";
      pass = !duplicateOnlyInjectBlockReferencesResult.success;
      detail = "expected duplicate onlyInjectBlockReferences entries to fail";
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
      name = "commands without default injected references render";
      pass = lib.hasInfix "Body" missingBoilerplateScope.commands."needs-preflight".embed;
      detail = "expected commands to render without implicit references when no block opts in";
    }
    {
      name = "dual commands without default injected references render";
      pass =
        lib.hasInfix "Body"
          missingDualBoilerplateScope.extraSkillsFromCommands."skills/dual-needs-preflight/SKILL".embed;
      detail = "expected command-derived skills to render without implicit references when no block opts in";
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
