{ pkgs, lib }:

/*
  Source-set renderer tests — exercise dendritic source-set normalization,
  flattening, cross-source-set block references, dual output, skill subfiles,
  harness filtering, outputPath, forHarness, and complete fixture rendering.
*/

let
  builders = import ../builders.nix { inherit pkgs lib; };
  sourcesLib = import ../../source-sets.nix;
  harnesses = import ../harnesses { renderFrontmatter = builders.renderFrontmatter; };

  mkScope = args: builders.makeScope ({ harness = harnesses.claude; } // args);
  mkOpencodeScope = args: builders.makeScope ({ harness = harnesses.opencode; } // args);

  # Command asSkill, skill asCommand, skill subfiles, harness
  # filtering, outputPath, and forHarness from source sets

  featureSourceDeclarations = builders.normalizeSourceDeclarations {
    "feature-test" = {
      blocks = {
        "feature-block" = {
          heading = "Feature Block";
          content = "Feature block body";
        };
      };

      commands = {
        "feature-cmd" =
          { scope }:
          {
            description = "Feature command that emits a skill";
            content = "Feature command uses ${scope.blocks."feature-block".reference}.";
            asSkill = true;
            onlyInjectBlockReferences = [ ];
          };
        "uses-feature-skill-ref" =
          { scope }:
          {
            description = "Command referencing a command-derived skill";
            content = "Feature skill reference: ${scope.skills."feature-cmd".reference}";
            onlyInjectBlockReferences = [ ];
          };
      };

      skills = {
        "feature-skill" = {
          kind = "directory";
          main =
            { scope }:
            {
              description = "Feature skill that emits a command";
              content = "Feature skill uses ${scope.blocks."feature-block".reference}.";
              asCommand = true;
            };
          files = {
            "refs/data.md" = {
              kind = "md";
              content = "Bundled source-set subfile data";
            };
          };
        };
      };

      instructions = {
        "rules/feature-rule" =
          { scope }:
          {
            heading = scope.forHarness {
              claude = "Feature Rule (Claude)";
              opencode = "Feature Rule (OpenCode)";
            };
            content = "Rule content with ${scope.blocks."feature-block".reference}.";
            outputPath = scope.forHarness {
              claude = "rules/feature-rule-claude.md";
              opencode = "rules/feature-rule-opencode.md";
            };
          };
      };

      agents = {
        "feature-agent" =
          { scope }:
          {
            description = "Feature agent filtered to Claude only";
            content = "Agent: ${scope.blocks."feature-block".reference}.";
            harnesses = [ "claude" ];
          };
      };
    };
  };

  featureScope = mkScope {
    sources = featureSourceDeclarations.sources;
  };

  featureOpencodeScope = mkOpencodeScope {
    sources = featureSourceDeclarations.sources;
  };

  # Complete source-set fixture package

  fixtureSourceDeclarations = builders.normalizeSourceDeclarations (
    import ./fixtures/source-set-fixture.nix
  );

  fixtureClaudeScope = mkScope {
    sources = fixtureSourceDeclarations.sources;
  };

  fixtureOpencodeScope = mkOpencodeScope {
    sources = fixtureSourceDeclarations.sources;
  };

  # Production owner auto-discovery fixtures

  autodiscoveredOwnerSources = sourcesLib.discoverSources ./fixtures/production-autodiscovery;

  autodiscoveredSourceDeclarations = builders.normalizeSourceDeclarations autodiscoveredOwnerSources;

  autodiscoveredScope = mkScope {
    sources = autodiscoveredSourceDeclarations.sources;
  };

  conflictingOwnerResult = builtins.tryEval (
    (builders.normalizeSourceDeclarations (sourcesLib.discoverSources ./fixtures/production-conflict))
    .sources.blocks
  );

  misleadingPathSources = builders.normalizeSourceDeclarations (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/misleading
  );

  misleadingPathScope = mkScope {
    sources = misleadingPathSources.sources;
  };

  defaultFragmentSources = builders.normalizeSourceDeclarations (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/default-fragment
  );

  defaultFragmentScope = mkScope {
    sources = defaultFragmentSources.sources;
  };

  relocationASources = builders.normalizeSourceDeclarations (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/relocation-a
  );

  relocationBSources = builders.normalizeSourceDeclarations (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/relocation-b
  );

  relocationAScope = mkScope {
    sources = relocationASources.sources;
  };

  relocationBScope = mkScope {
    sources = relocationBSources.sources;
  };

  helperSkipSources = builders.normalizeSourceDeclarations (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/helper-skip
  );

  helperSkipScope = mkScope {
    sources = helperSkipSources.sources;
  };

  rootFragmentSources = builders.normalizeSourceDeclarations (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/root-fragments
  );

  rootFragmentScope = mkScope {
    sources = rootFragmentSources.sources;
  };

  # High-level source roots

  sourceRootsOnlyRendered = import ../default.nix {
    inherit pkgs lib;
    sourceRoots = [ ./fixtures/fragment-semantics/helper-skip ];
  };

  additiveResolvedSources = builders.normalizeSourceDeclarations (
    sourcesLib.resolveSources {
      sourceRoots = [ ./fixtures/fragment-semantics/helper-skip ];
      sources.explicit-owner.commands."explicit-command" = {
        description = "Explicit command";
        content = "Explicit low-level source";
        onlyInjectBlockReferences = [ ];
      };
    }
  );

  additiveSourceRootsScope = mkScope {
    sources = additiveResolvedSources.sources;
  };

  # A command carrying a Claude-only context must not abort the opencode render.
  claudeOnlyContextSources = builders.normalizeSourceDeclarations {
    "ctx-test" = {
      commands = {
        "compacting-cmd" = {
          description = "Command with a Claude-only context";
          content = "Body";
          context = "compact";
          onlyInjectBlockReferences = [ ];
        };
      };
    };
  };

  claudeOnlyContextOpencodeScope = mkOpencodeScope {
    sources = claudeOnlyContextSources.sources;
  };

  # Discovered fragment lacking the nixantic.sources wrapper must fail loudly.
  nonSourceFragmentResult = builtins.tryEval (
    sourcesLib.discoverSources ./fixtures/fragment-semantics/non-source
  );

  # The same root listed twice rediscovers identical files; dedup keeps this
  # from being mistaken for a conflicting declaration.
  repeatedRootSources = builders.normalizeSourceDeclarations (
    sourcesLib.resolveSources {
      sourceRoots = [
        ./fixtures/fragment-semantics/helper-skip
        ./fixtures/fragment-semantics/helper-skip
      ];
    }
  );

  repeatedRootScope = mkScope {
    sources = repeatedRootSources.sources;
  };

  duplicateSourceRootsResult = builtins.tryEval (
    (builders.normalizeSourceDeclarations (
      sourcesLib.resolveSources {
        sourceRoots = [
          ./fixtures/fragment-semantics/relocation-a
          ./fixtures/fragment-semantics/relocation-b
        ];
      }
    )).sources.commands
  );

  duplicateSourceRootAndExplicitResult = builtins.tryEval (
    (builders.normalizeSourceDeclarations (
      sourcesLib.resolveSources {
        sourceRoots = [ ./fixtures/fragment-semantics/helper-skip ];
        sources.explicit-owner.blocks."helper-visible-block" = {
          heading = "Explicit duplicate";
          content = "Explicit duplicate body";
        };
      }
    )).sources.blocks
  );

  # ── Duplicate source-set artifact keys ──

  duplicateSourceResult = builtins.tryEval (
    sourcesLib.resolveSources {
      sources = {
        "ss-owner-a" = {
          blocks.duplicate-key = {
            heading = "Owner A";
            content = "A";
          };
        };
        "ss-owner-b" = {
          blocks.duplicate-key = {
            heading = "Owner B";
            content = "B";
          };
        };
      };
    }
  );

  # ── Multi-owner source-set flattening with owner provenance ──

  multiOwnerSourceDeclarations = builders.normalizeSourceDeclarations {
    "owner-alpha" = {
      blocks = {
        "alpha-block" = {
          heading = "Alpha Block";
          content = "Content from owner alpha";
        };
      };
      commands = {
        "alpha-cmd" =
          { scope }:
          {
            description = "Alpha command";
            content = "Alpha command: ${scope.blocks."alpha-block".reference}";
            onlyInjectBlockReferences = [ ];
          };
      };
    };
    "owner-beta" = {
      blocks = {
        "beta-block" = {
          heading = "Beta Block";
          content = "Content from owner beta";
        };
      };
      agents = {
        "beta-agent" =
          { scope }:
          {
            description = "Beta agent";
            content = "Beta agent: ${scope.blocks."beta-block".reference}";
          };
      };
    };
  };

  multiOwnerScope = mkScope {
    sources = multiOwnerSourceDeclarations.sources;
  };

  # ── Cross-owner source-set block references ──

  crossOwnerSourceDeclarations = builders.normalizeSourceDeclarations {
    "owner-one" = {
      blocks = {
        "shared-block" = {
          heading = "Shared Block";
          content = "Shared content from owner one";
        };
      };
    };
    "owner-two" = {
      commands = {
        "ref-cmd" =
          { scope }:
          {
            description = "Command referencing cross-owner block";
            content = "CMD: ${scope.blocks."shared-block".reference}";
            onlyInjectBlockReferences = [ ];
          };
      };
    };
  };

  crossOwnerScope = mkScope {
    sources = crossOwnerSourceDeclarations.sources;
  };

  # ── Self-reference failure for source-set function ──

  selfRefSourceSets = builders.normalizeSourceDeclarations {
    "self-ref-ss" = {
      commands."self-ref-cmd" =
        { scope }:
        {
          description = "Self-referential source-set command";
          content = scope.commands."self-ref-cmd".embed or (throw "processed command content unavailable");
        };
    };
  };

  selfRefSourceSetResult = builtins.tryEval (
    (mkScope {
      sources = selfRefSourceSets.sources;
    }).commands."self-ref-cmd".embed
  );

  # ── Test cases ──

  cases = [
    # Source-set command asSkill
    {
      name = "source-set command asSkill produces skill instruction";
      pass = builtins.hasAttr "skills/feature-cmd/SKILL" featureScope.instructions;
      detail = "expected source-set command with asSkill to generate skill instruction";
    }

    {
      name = "source-set command asSkill exposes raw skill reference";
      pass =
        lib.hasInfix "Feature skill reference: (See skill: feature-cmd)"
          featureScope.commands."uses-feature-skill-ref".embed;
      detail = "expected command-derived skills from source-set functions to be available through scope.skills metadata";
    }

    # Source-set skill asCommand
    {
      name = "source-set skill asCommand produces command instruction";
      pass = builtins.hasAttr "commands/feature-skill" featureScope.instructions;
      detail = "expected source-set skill with asCommand to generate command instruction";
    }

    # Source-set skill bundled markdown subfile
    {
      name = "source-set skill bundled subfile";
      pass =
        lib.hasInfix "Bundled source-set subfile data"
          featureScope.skillFiles."skills/feature-skill/refs/data.md".embed;
      detail = "expected source-set skill to expose bundled markdown subfile via skillFiles";
    }

    # Source-set instruction outputPath and forHarness
    {
      name = "source-set instruction outputPath and forHarness";
      pass =
        featureScope.instructions."rules/feature-rule".outputPath == "rules/feature-rule-claude.md"
        &&
          featureOpencodeScope.instructions."rules/feature-rule".outputPath
          == "rules/feature-rule-opencode.md"
        && lib.hasInfix "Feature Rule (Claude)" featureScope.instructions."rules/feature-rule".embed
        &&
          lib.hasInfix "Feature Rule (OpenCode)"
            featureOpencodeScope.instructions."rules/feature-rule".embed;
      detail = "expected source-set instruction to select harness-specific outputPath and heading via forHarness";
    }

    # Source-set agent harness filtering
    {
      name = "source-set agent harness filtering";
      pass =
        builtins.hasAttr "feature-agent" featureScope.agents
        && !(builtins.hasAttr "feature-agent" featureOpencodeScope.agents);
      detail = "expected source-set agent to appear only for claude harness";
    }

    # Source-set fixture renders
    {
      name = "source-set fixture renders harness-specific outputPath";
      pass =
        fixtureClaudeScope.instructions.main.outputPath == "CLAUDE.md"
        && fixtureOpencodeScope.instructions.main.outputPath == "AGENTS.md";
      detail = "expected source-set fixture to select harness-specific outputPath";
    }

    # Source-set fixture embeds block content
    {
      name = "source-set fixture embeds block content";
      pass =
        lib.hasInfix "Fixture-Generated Instructions" fixtureClaudeScope.instructions.main.embed
        && lib.hasInfix "This block was authored through the source-set fixture" fixtureClaudeScope.instructions.main.embed;
      detail = "expected source-set fixture to embed test block content in main instruction";
    }

    # Source-set fixture harness-specific headings
    {
      name = "source-set fixture harness-specific headings";
      pass =
        lib.hasInfix "# Claude" fixtureClaudeScope.instructions.main.embed
        && lib.hasInfix "# OpenCode" fixtureOpencodeScope.instructions.main.embed;
      detail = "expected source-set fixture to emit harness-specific headings";
    }

    # Production owner auto-discovery
    {
      name = "production source-set discovery sorts directories deterministically";
      pass =
        builtins.attrNames autodiscoveredOwnerSources == [
          "alpha-owner"
          "beta-owner"
        ];
      detail = "expected source-set discovery to use sorted directory names, independent of filesystem iteration order";
    }
    {
      name = "production source-set discovery loads new directories without registry edits";
      pass =
        builtins.hasAttr "alpha-block" autodiscoveredScope.blocks
        && builtins.hasAttr "beta-command" autodiscoveredScope.commands
        && builtins.hasAttr "beta-skill" autodiscoveredScope.skills
        && lib.hasInfix "Beta command sees (See: Alpha Block)" autodiscoveredScope.commands.beta-command.embed;
      detail = "expected discovered source-set directories to contribute flat blocks, commands, and skills";
    }
    {
      name = "production source-set discovery preserves skill subfiles";
      pass =
        lib.hasInfix "Autodiscovered skill reference"
          autodiscoveredScope.skillFiles."skills/beta-skill/reference.md".embed;
      detail = "expected discovered directory skills to retain bundled markdown subfiles";
    }
    {
      name = "production source-set discovery duplicate keys fail with provenance";
      pass = !conflictingOwnerResult.success;
      detail = "expected duplicate artifact keys across discovered owners to fail during source-set normalization";
    }
    {
      name = "fragment discovery uses exported shape over misleading path";
      pass =
        builtins.hasAttr "shape-command" misleadingPathScope.commands
        && !(builtins.hasAttr "not-a-block" misleadingPathScope.blocks)
        && lib.hasInfix "classified by exported shape" misleadingPathScope.commands."shape-command".embed;
      detail = "expected a file under blocks/ exporting commands.* to render as a command, not a block";
    }
    {
      name = "fragment discovery treats default.nix as ordinary fragment";
      pass =
        builtins.hasAttr "default-fragment-block" defaultFragmentScope.blocks
        &&
          lib.hasInfix "default.nix is an ordinary fragment"
            defaultFragmentScope.blocks."default-fragment-block".body;
      detail = "expected default.nix to contribute normal source-set data with no reserved semantics";
    }
    {
      name = "fragment discovery includes root default.nix and lib.nix";
      pass =
        builtins.hasAttr "root-default-block" rootFragmentScope.blocks
        && builtins.hasAttr "root-lib-command" rootFragmentScope.commands;
      detail = "expected root-level default.nix and lib.nix to match the documented fragment contract";
    }
    {
      name = "fragment relocation preserves runtime meaning";
      pass =
        relocationAScope.commands."relocated-command".embed
        == relocationBScope.commands."relocated-command".embed
        &&
          relocationAScope.commands."relocated-command".outputPath
          == relocationBScope.commands."relocated-command".outputPath;
      detail = "expected identical exported source-set data to render the same from different physical paths";
    }
    {
      name = "fragment discovery skips helper-only paths without semantics";
      pass =
        builtins.hasAttr "helper-visible-block" helperSkipScope.blocks
        && !(builtins.hasAttr "ignored" helperSkipScope.blocks);
      detail = "expected _support paths to be excluded only as helper code, while neighboring fragments import normally";
    }
    {
      name = "sourceRoots render through direct mkInstructions surface";
      pass = builtins.hasAttr "helper-visible-block" sourceRootsOnlyRendered.blocks.claude;
      detail = "expected direct renderer sourceRoots input to discover and render source fragments";
    }
    {
      name = "sourceRoots and explicit sources merge additively";
      pass =
        builtins.hasAttr "helper-visible-block" additiveSourceRootsScope.blocks
        && builtins.hasAttr "explicit-command" additiveSourceRootsScope.commands;
      detail = "expected high-level discovered roots and low-level explicit sources to both contribute artifacts";
    }
    {
      name = "claude-only context does not abort opencode render";
      pass =
        builtins.hasAttr "compacting-cmd" claudeOnlyContextOpencodeScope.commands
        && !(lib.hasInfix "subtask" claudeOnlyContextOpencodeScope.commands."compacting-cmd".embed);
      detail = "expected an opencode command with a Claude-only context to render without subtask and without aborting";
    }
    {
      name = "discovered non-source fragment fails loudly";
      pass = !nonSourceFragmentResult.success;
      detail = "expected a discovered .nix lacking nixantic.sources to fail discovery, not be silently dropped";
    }
    {
      name = "repeated sourceRoot is deduped, not a false duplicate";
      pass = builtins.hasAttr "helper-visible-block" repeatedRootScope.blocks;
      detail = "expected listing the same root twice to render once without a false-positive duplicate-key failure";
    }
    {
      name = "duplicate sourceRoots fail explicitly";
      pass = !duplicateSourceRootsResult.success;
      detail = "expected duplicate artifact keys across high-level roots to fail before rendering";
    }
    {
      name = "duplicate sourceRoots and explicit sources fail explicitly";
      pass = !duplicateSourceRootAndExplicitResult.success;
      detail = "expected duplicate artifact keys across discovered roots and explicit sources to fail before rendering";
    }

    # Multi-owner flattening
    {
      name = "multi-owner flattening exposes all artifacts in flat scope";
      pass =
        builtins.hasAttr "alpha-block" multiOwnerScope.blocks
        && builtins.hasAttr "beta-block" multiOwnerScope.blocks
        && builtins.hasAttr "alpha-cmd" multiOwnerScope.commands
        && builtins.hasAttr "beta-agent" multiOwnerScope.agents;
      detail = "expected all artifacts from both owners to appear in flat scope after normalization";
    }

    # Cross-owner source-set block references
    {
      name = "cross-owner source-set block references resolve through flat scope.blocks";
      pass = lib.hasInfix "Shared Block" crossOwnerScope.commands."ref-cmd".embed;
      detail = "expected owner-two command to reference owner-one block through flat scope.blocks";
    }

    # Duplicate source-set artifact keys across owners
    {
      name = "duplicate source-set artifact keys fail during resolveSources";
      pass = !duplicateSourceResult.success;
      detail = "expected duplicate source-set block key across owners to fail in resolveSources";
    }

    # Self-reference failure for source-set function referencing its own processed artifact
    {
      name = "self-referential source-set function fails";
      pass = !selfRefSourceSetResult.success;
      detail = "expected source-set command referencing its own processed scope.commands entry to fail";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
