{ pkgs, lib }:

/*
  Source-set renderer tests — exercise dendritic source-set normalization,
  flattening, cross-source-set block references, dual output, skill subfiles,
  harness filtering, outputPath, forHarness, and complete options-only
  fixture rendering.
*/

let
  builders = import ../builders.nix { inherit pkgs lib; };
  harnesses = {
    claude = import ../harnesses/claude.nix { renderFrontmatter = builders.renderFrontmatter; };
    opencode = import ../harnesses/opencode.nix { renderFrontmatter = builders.renderFrontmatter; };
  };

  mkScope = args: builders.makeScope ({ harness = harnesses.claude; } // args);
  mkOpencodeScope = args: builders.makeScope ({ harness = harnesses.opencode; } // args);

  # Source-set command referencing a directory block in mixed mode

  mixedSourceSetRef = builders.normalizeSourceSets {
    "mixed-test" = {
      commands."source-set-dir-ref" =
        { scope }:
        {
          description = "Source-set command referencing a directory block";
          content = "Using directory block: ${scope.blocks."deep-thinking".reference}.";
          noInjectPreFlight = true;
        };
    };
  };

  mixedSourceSetScope = mkScope {
    sourceMode = "mixed";
    sources = mixedSourceSetRef.sources;
    sourceProvenance = mixedSourceSetRef.provenance;
  };

  # Command asSkill, skill asCommand, skill subfiles, harness
  # filtering, outputPath, and forHarness from source sets

  featureSourceSets = builders.normalizeSourceSets {
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
            noInjectPreFlight = true;
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
    sourceMode = "options";
    sources = featureSourceSets.sources;
    sourceProvenance = featureSourceSets.provenance;
  };

  featureOpencodeScope = mkOpencodeScope {
    sourceMode = "options";
    sources = featureSourceSets.sources;
    sourceProvenance = featureSourceSets.provenance;
  };

  # Complete options-only fixture package without directory sources

  fixtureSourceSets = builders.normalizeSourceSets (import ./fixtures/options-only-source-set.nix);

  fixtureClaudeScope = mkScope {
    sourceMode = "options";
    sources = fixtureSourceSets.sources;
    sourceProvenance = fixtureSourceSets.provenance;
  };

  fixtureOpencodeScope = mkOpencodeScope {
    sourceMode = "options";
    sources = fixtureSourceSets.sources;
    sourceProvenance = fixtureSourceSets.provenance;
  };

  # ── Duplicate source-set artifact keys ──

  duplicateSourceSetResult = builtins.tryEval (
    (builders.normalizeSourceSets {
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
    }).sources.blocks
  );

  # ── Duplicate mixed directory/source-set keys ──

  duplicateMixedSsdNormalized = builders.normalizeSourceSets {
    "ss-owner" = {
      blocks."pre-flight" = {
        heading = "Duplicate Pre Flight";
        content = "Duplicate from source set";
      };
    };
  };

  duplicateMixedSsdResult = builtins.tryEval (
    (mkScope {
      sourceMode = "mixed";
      sources = duplicateMixedSsdNormalized.sources;
      sourceProvenance = duplicateMixedSsdNormalized.provenance;
    }).rawBlocks
  );

  # ── Multi-owner source-set flattening with owner provenance ──

  multiOwnerSourceSets = builders.normalizeSourceSets {
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
            noInjectPreFlight = true;
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
    sourceMode = "options";
    sources = multiOwnerSourceSets.sources;
    sourceProvenance = multiOwnerSourceSets.provenance;
  };

  # ── Cross-owner source-set block references ──

  crossOwnerSourceSets = builders.normalizeSourceSets {
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
            noInjectPreFlight = true;
          };
      };
    };
  };

  crossOwnerScope = mkScope {
    sourceMode = "options";
    sources = crossOwnerSourceSets.sources;
    sourceProvenance = crossOwnerSourceSets.provenance;
  };

  # ── Self-reference failure for source-set function ──

  selfRefSourceSets = builders.normalizeSourceSets {
    "self-ref-ss" = {
      commands."self-ref-cmd" =
        { scope }:
        {
          description = "Self-referential source-set command";
          content = scope.commands."self-ref-cmd".embed;
        };
    };
  };

  selfRefSsdResult = builtins.tryEval (
    (mkScope {
      sourceMode = "options";
      sources = selfRefSourceSets.sources;
      sourceProvenance = selfRefSourceSets.provenance;
    }).commands."self-ref-cmd".embed
  );

  # ── Test cases ──

  cases = [
    # Source-set command references directory block in mixed mode
    {
      name = "source-set command references directory block in mixed mode";
      pass = lib.hasInfix "<deep-thinking>" mixedSourceSetScope.commands."source-set-dir-ref".embed;
      detail = "expected source-set command to reference directory block through flat scope.blocks";
    }

    # Source-set command asSkill
    {
      name = "source-set command asSkill produces skill instruction";
      pass = builtins.hasAttr "skills/feature-cmd/SKILL" featureScope.instructions;
      detail = "expected source-set command with asSkill to generate skill instruction";
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

    # Options-only fixture renders without directory sources
    {
      name = "options-only fixture renders harness-specific outputPath";
      pass =
        fixtureClaudeScope.instructions.main.outputPath == "CLAUDE.md"
        && fixtureOpencodeScope.instructions.main.outputPath == "AGENTS.md";
      detail = "expected options-only fixture to select harness-specific outputPath";
    }

    # Options-only fixture embeds block content
    {
      name = "options-only fixture embeds block content";
      pass =
        lib.hasInfix "Fixture-Generated Instructions" fixtureClaudeScope.instructions.main.embed
        && lib.hasInfix "This block was authored through the options-only source-set fixture" fixtureClaudeScope.instructions.main.embed;
      detail = "expected options-only fixture to embed test block content in main instruction";
    }

    # Options-only fixture harness-specific headings
    {
      name = "options-only fixture harness-specific headings";
      pass =
        lib.hasInfix "# Claude" fixtureClaudeScope.instructions.main.embed
        && lib.hasInfix "# OpenCode" fixtureOpencodeScope.instructions.main.embed;
      detail = "expected options-only fixture to emit harness-specific headings";
    }

    # Multi-owner flattening with owner provenance
    {
      name = "multi-owner flattening keeps correct owner provenance";
      pass =
        lib.hasInfix "owner-alpha" (builtins.head multiOwnerSourceSets.provenance.blocks."alpha-block")
        && lib.hasInfix "owner-beta" (builtins.head multiOwnerSourceSets.provenance.blocks."beta-block")
        && lib.hasInfix "owner-alpha" (builtins.head multiOwnerSourceSets.provenance.commands."alpha-cmd")
        && lib.hasInfix "owner-beta" (builtins.head multiOwnerSourceSets.provenance.agents."beta-agent");
      detail = "expected each artifact to report its declaring owner in provenance after multi-owner flattening";
    }
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

    # Duplicate source-set artifact keys with owner/kind/key error text
    {
      name = "duplicate source-set artifact keys fail with owner/kind/key error";
      pass = !duplicateSourceSetResult.success;
      detail = "expected duplicate source-set block key to fail with owner provenance during normalizeSourceSets";
    }

    # Duplicate mixed directory/source-set keys with provider/owner/kind/key error text
    {
      name = "duplicate mixed directory and source-set artifact keys fail";
      pass = !duplicateMixedSsdResult.success;
      detail = "expected mixed directory/source-set duplicate to fail with provider/owner provenance";
    }

    # Self-reference failure for source-set function referencing its own processed artifact
    {
      name = "self-referential source-set function fails";
      pass = !selfRefSsdResult.success;
      detail = "expected source-set command referencing its own processed scope.commands entry to fail";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
