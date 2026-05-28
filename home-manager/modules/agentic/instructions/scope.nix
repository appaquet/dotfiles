{
  mkBlock,
  mkInstructions,
  mkAgent,
  mkSkill,
  mkSkillFile,
  mkCommand,
  forHarness,
  renderFrontmatter,
  importDir,
  importFlatTree,
  importBlocksTree,
  importSkillsDir,
  pkgs,
  lib,
}:

/*
  Scope pipeline — imports authored instruction sources, applies harness filtering,
  injects generated defaults, calls constructors, and assembles the final
  instruction map. The per-artifact authoring contract is documented on the
  constructors in builders.nix.

  Pipeline stages (makeScope):
    1. addRawContent        — import all authored files from disk
    2. addProcessedContent  — filter by harness, inject defaults, call mk* constructors
    3. addDualOutput        — cross-artifact outputs (command→skill, skill→command)
    4. addInstructions      — assemble final instruction map, detect key collisions

  Each stage adds attrs to a lib.fix self-referencing record. Stages reference
  earlier stages via `self.raw*`, `self.agents`, `self.commands`, etc.
*/

let
  # scopeApi :: { mkBlock, mkInstructions, mkAgent, mkSkill, mkCommand, mkSkillFile, importSkillsDir, importFlatTree, importBlocksTree, forHarness, renderFrontmatter }
  #   Constructors and helpers bound as `self.scopeApi` within the scope. Enables
  #   self-referential constructor calls throughout the pipeline (e.g.
  #   self.scopeApi.mkAgent). See builders.nix for constructor signatures.
  scopeApi = {
    inherit
      mkBlock
      mkInstructions
      mkAgent
      mkSkill
      mkCommand
      mkSkillFile
      importSkillsDir
      importFlatTree
      importBlocksTree
      forHarness
      renderFrontmatter
      ;
  };

  # ── Helpers ────────────────────────────────────────────────────────────────

  # isEnabledFor :: self -> val -> bool
  #   Resolves dual-output flags (asSkill, asCommand). Accepts a boolean or a
  #   per-harness attrset (e.g. { claude = true; opencode = false; }). For
  #   attrsets, selects the active harness key; absent = false.
  isEnabledFor =
    self: val:
    if builtins.isBool val then
      val
    else if builtins.isAttrs val then
      val.${self.harness.name} or false
    else
      false;

  # isForHarness :: self -> data -> bool
  #   True if data has no `harnesses` field (available to all), or if the active
  #   harness name is listed in data.harnesses.
  isForHarness =
    self: data: !builtins.hasAttr "harnesses" data || builtins.elem self.harness.name data.harnesses;

  # filterForHarness :: self -> attrs -> attrs
  #   Filters an attrset by isForHarness, removing entries restricted to other harnesses.
  filterForHarness = self: lib.filterAttrs (_: data: isForHarness self data);

  # filterSkillsForHarness :: self -> attrs -> attrs
  #   Same as filterForHarness but checks entry.main (skills use { main, files } structure).
  filterSkillsForHarness = self: lib.filterAttrs (_: entry: isForHarness self entry.main);

  # injectCommandPreFlight :: self -> data -> data
  #   Appends the pre-flight block reference to command content, unless
  #   noInjectPreFlight is true. Consumed by addProcessedContent and addDualOutput.
  injectCommandPreFlight =
    self: data:
    if data.noInjectPreFlight or false then
      data
    else
      data
      // {
        content = "${data.content}\n\n${self.blocks."pre-flight".reference}";
      };

  # ── Pipeline stages ────────────────────────────────────────────────────────

  # Stage 1: Import all authored sources as raw attrsets.
  #
  # Produces:
  #   rawBlocks               — blocks/**/*.nix from global and local blocks dirs
  #   rawAgents               — agents/**/*.nix, flattened by filename stem
  #   rawCommands             — commands/**/*.nix, flattened by filename stem
  #   rawSkills               — skills/<dir>/default.nix → { <dir> = { main, files }; }
  #   rawAuthoredInstructions — instructions/**/*.nix (recursive)
  #
  # Imports receive { scope = self } as args; each .nix file is called with scope.
  addRawContent =
    self:
    let
      args = {
        scope = self;
      };
    in
    {
      rawBlocks = importBlocksTree {
        inherit args;
        roots = [
          ./blocks
          ./agents
          ./commands
          ./skills
          ./instructions/rules
        ];
      };
      rawAgents = importFlatTree {
        inherit args;
        dir = ./agents;
        reservedDirs = [ "blocks" ];
      };
      rawCommands = importFlatTree {
        inherit args;
        dir = ./commands;
        reservedDirs = [ "blocks" ];
      };
      rawSkills = importSkillsDir {
        inherit args;
        dir = ./skills;
      };
      rawAuthoredInstructions = importDir {
        inherit args;
        dir = ./instructions;
        recursive = true;
        reservedDirs = [ "blocks" ];
      };
    };

  # Stage 2: Filter by harness, inject defaults, call constructors.
  #
  # Consumes: self.raw*
  # Produces:
  #   blocks     — all blocks → mkBlock (no filtering)
  #   agents     — filtered rawAgents → mkAgent(harness, name)
  #   commands   — filtered rawCommands → pre-flight injection → mkCommand(harness, kind, outputPath, name)
  #   skills     — filtered rawSkills → mkSkill(harness, kind="directory", outputPath, name)
  #   skillFiles — filtered skill sub-files → mkSkillFile (nix) or raw pass-through (md)
  addProcessedContent = self: {
    blocks = lib.mapAttrs (_: data: self.scopeApi.mkBlock data) self.rawBlocks;

    agents = lib.mapAttrs (
      key: data:
      self.scopeApi.mkAgent ({ harness = self.harness; } // data // { name = data.name or key; })
    ) (filterForHarness self self.rawAgents);

    commands = lib.mapAttrs (
      key: data:
      let
        commandData = injectCommandPreFlight self data;
      in
      self.scopeApi.mkCommand (
        {
          harness = self.harness;
          kind = "flat";
          outputPath = "commands/${data.name or key}.md";
        }
        // commandData
        // {
          name = data.name or key;
        }
      )
    ) (filterForHarness self self.rawCommands);

    skills = lib.mapAttrs (
      key: entry:
      self.scopeApi.mkSkill (
        {
          harness = self.harness;
          kind = "directory";
          outputPath = "skills/${key}/SKILL.md";
        }
        // entry.main
        // {
          name = key;
        }
      )
    ) (filterSkillsForHarness self self.rawSkills);

    skillFiles = builtins.listToAttrs (
      builtins.concatLists (
        lib.mapAttrsToList (
          skillKey: entry:
          lib.mapAttrsToList (
            subPath: subData:
            let
              fullPath = "skills/${skillKey}/${subPath}";
              processed =
                if subData.kind == "nix" then
                  self.scopeApi.mkSkillFile {
                    content = subData.content;
                    outputPath = fullPath;
                  }
                else
                  {
                    embed = subData.content;
                    outputPath = fullPath;
                  };
            in
            {
              name = fullPath;
              value = processed;
            }
          ) entry.files
        ) (filterSkillsForHarness self self.rawSkills)
      )
    );
  };

  # Stage 3: Create cross-artifact dual outputs.
  #
  # Consumes: self.rawCommands, self.rawSkills, self.blocks (via injectCommandPreFlight)
  # Produces:
  #   extraSkillsFromCommands — commands with asSkill flag → mkSkill(kind="directory")
  #   extraCommandsFromSkills — skills with asCommand flag → mkSkill(kind="flat")
  #
  # Dual-output flags (asSkill, asCommand) accept bool or per-harness attrsets,
  # resolved via isEnabledFor.
  addDualOutput = self: {
    extraSkillsFromCommands = lib.listToAttrs (
      builtins.concatLists (
        lib.mapAttrsToList (
          key: data:
          if data ? asSkill && isEnabledFor self data.asSkill then
            let
              skillName = data.name or key;
              commandData = injectCommandPreFlight self data;
            in
            [
              {
                name = "skills/${skillName}/SKILL";
                value = self.scopeApi.mkSkill (
                  {
                    harness = self.harness;
                    kind = "directory";
                    outputPath = "skills/${skillName}/SKILL.md";
                  }
                  // commandData
                  // {
                    name = skillName;
                  }
                );
              }
            ]
          else
            [ ]
        ) (filterForHarness self self.rawCommands)
      )
    );

    extraCommandsFromSkills = lib.listToAttrs (
      builtins.concatLists (
        lib.mapAttrsToList (
          key: entry:
          if entry.main ? asCommand && isEnabledFor self entry.main.asCommand then
            let
              cmdName = entry.main.name or key;
              commandData = injectCommandPreFlight self entry.main;
            in
            [
              {
                name = "commands/${cmdName}";
                value = self.scopeApi.mkSkill (
                  {
                    harness = self.harness;
                    kind = "flat";
                    outputPath = "commands/${cmdName}.md";
                  }
                  // commandData
                  // {
                    name = cmdName;
                  }
                );
              }
            ]
          else
            [ ]
        ) (filterSkillsForHarness self self.rawSkills)
      )
    );
  };

  # Stage 4: Assemble the final instruction map.
  #
  # Consumes: self.rawAuthoredInstructions, self.agents, self.commands,
  #           self.skills, self.extraSkillsFromCommands, self.extraCommandsFromSkills
  # Produces:
  #   authoredInstructions  — filtered raw instructions → mkInstructions
  #   agentInstructions     — agents keyed as "agents/<name>"
  #   commandInstructions   — commands keyed as "commands/<key>"
  #   skillMainInstructions — skills keyed as "skills/<key>/SKILL"
  #   collisions            — keys appearing in multiple instruction sources
  #   instructions          — merged map; asserts no collisions
  #
  # Merge order (later attrs override earlier on collision, but collisions assert
  # catches all conflicts before assembly):
  #   authoredInstructions → agentInstructions → commandInstructions →
  #   extraCommandsFromSkills → skillMainInstructions → extraSkillsFromCommands
  addInstructions = self: {
    authoredInstructions = lib.mapAttrs (_: data: self.scopeApi.mkInstructions data) (
      filterForHarness self self.rawAuthoredInstructions
    );

    agentInstructions = lib.mapAttrs' (
      name: agent: lib.nameValuePair "agents/${name}" agent
    ) self.agents;

    commandInstructions = lib.mapAttrs' (
      key: _: lib.nameValuePair "commands/${key}" self.commands.${key}
    ) self.commands;

    skillMainInstructions = lib.mapAttrs' (
      key: _: lib.nameValuePair "skills/${key}/SKILL" self.skills.${key}
    ) self.skills;

    collisions =
      builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.agentInstructions)
      ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.commandInstructions)
      ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.skillMainInstructions)
      ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.extraCommandsFromSkills)
      ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.extraSkillsFromCommands)
      ++ builtins.attrNames (lib.intersectAttrs self.commandInstructions self.extraCommandsFromSkills)
      ++ builtins.attrNames (lib.intersectAttrs self.skillMainInstructions self.extraSkillsFromCommands);

    instructions =
      assert
        self.collisions == [ ]
        || builtins.throw "Generated instructions collide with authored instructions: ${builtins.concatStringsSep ", " self.collisions}";
      self.authoredInstructions
      // self.agentInstructions
      // self.commandInstructions
      // self.extraCommandsFromSkills
      // self.skillMainInstructions
      // self.extraSkillsFromCommands;
  };

  # makeScope :: harness -> scope
  #   Creates a harness-specific instruction scope by executing the 4-stage
  #   pipeline. The returned scope is a lib.fix self-referencing record
  #   containing all imported and processed instruction data for the given
  #   harness.
  #
  #   Base attrs (before pipeline stages):
  #     harness    — the harness definition (e.g. from harnesses/claude.nix)
  #     scopeApi   — constructors and helpers available as self.scopeApi.*
  #     forHarness — harness-specific value selector bound to this scope
  #
  #   Pipeline stages are merged via // in order. Each stage reads from `self`
  #   attrs produced by earlier stages.
  makeScope =
    harness:
    lib.fix (
      self:
      {
        inherit harness scopeApi;

        forHarness = forHarness self;
      }
      // addRawContent self
      // addProcessedContent self
      // addDualOutput self
      // addInstructions self
    );
in
{
  inherit
    scopeApi
    makeScope
    injectCommandPreFlight
    addDualOutput
    addInstructions
    ;
}
