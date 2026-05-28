{
  mkBlock,
  mkInstructions,
  mkAgent,
  mkSkill,
  mkSkillFile,
  mkCommand,
  forHarness,
  renderFrontmatter,
  pkgs,
  lib,
}:

/*
  Scope pipeline — imports authored instruction sources, applies harness filtering,
  injects generated defaults, calls constructors, and assembles the final
  instruction map. The per-artifact authoring contract is documented on the
  constructors in builders.nix.

  Pipeline stages (makeScope):
    1. addRawContent        — normalize source inputs
    2. addProcessedContent  — filter by harness, inject defaults, call mk* constructors
    3. addDualOutput        — cross-artifact outputs (command→skill, skill→command)
    4. addInstructions      — assemble final instruction map, detect key collisions

  Each stage adds attrs to a lib.fix self-referencing record. Stages reference
  earlier stages via `self.raw*`, `self.agents`, `self.commands`, etc.
*/

let
  # scopeApi :: { mkBlock, mkInstructions, mkAgent, mkSkill, mkCommand, mkSkillFile, forHarness, renderFrontmatter }
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

  applySource =
    self: value:
    if builtins.isFunction value then
      value {
        scope = self // {
          agents = builtins.throw "Nixantic source functions must not reference processed scope.agents while raw sources are being normalized";
          commands = builtins.throw "Nixantic source functions must not reference processed scope.commands while raw sources are being normalized";
          skills = builtins.throw "Nixantic source functions must not reference processed scope.skills while raw sources are being normalized";
          instructions = builtins.throw "Nixantic source functions must not reference final scope.instructions while raw sources are being normalized";
        };
      }
    else
      value;

  emptySources = {
    blocks = { };
    agents = { };
    commands = { };
    skills = { };
    instructions = { };
  };

  sourceKinds = {
    blocks = "block";
    agents = "agent";
    commands = "command";
    skills = "skill";
    instructions = "authored instruction";
  };

  sourceKindNames = builtins.attrNames sourceKinds;

  normalizeSources = sources: emptySources // sources;

  normalizeSourceDeclarations =
    sourceOwners:
    let
      owners = builtins.attrNames sourceOwners;

      sourceEntriesFor =
        kind:
        builtins.concatLists (
          map (
            owner:
            lib.mapAttrsToList (key: value: {
              inherit
                key
                owner
                value
                ;
            }) (sourceOwners.${owner}.${kind} or { })
          ) owners
        );

      duplicateEntries =
        entries:
        lib.filterAttrs (_: matches: builtins.length matches > 1) (lib.groupBy (entry: entry.key) entries);

      checkedEntriesFor =
        kind:
        let
          entries = sourceEntriesFor kind;
          duplicates = duplicateEntries entries;
          duplicateMessages = lib.mapAttrsToList (
            key: matches:
            "${sourceKinds.${kind}} '${key}' declared by source owners: ${
              builtins.concatStringsSep ", " (map (entry: entry.owner) matches)
            }"
          ) duplicates;
        in
        assert
          duplicateMessages == [ ]
          || builtins.throw "Duplicate nixantic source keys: ${builtins.concatStringsSep "; " duplicateMessages}";
        entries;
    in
    {
      sources = lib.genAttrs sourceKindNames (
        kind:
        builtins.listToAttrs (
          map (entry: {
            name = entry.key;
            value = entry.value;
          }) (checkedEntriesFor kind)
        )
      );

      provenance = lib.genAttrs sourceKindNames (
        kind:
        builtins.listToAttrs (
          map (entry: {
            name = entry.key;
            value = [ "source '${entry.owner}'" ];
          }) (checkedEntriesFor kind)
        )
      );
    };

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

  # Stage 1: Normalize raw source artifacts.
  #
  # Produces:
  #   rawBlocks               — source blocks, flattened by artifact key
  #   rawAgents               — source agents, flattened by artifact key
  #   rawCommands             — source commands, flattened by artifact key
  #   rawSkills               — source skills, flattened by artifact key
  #   rawAuthoredInstructions — source instructions, flattened by artifact key
  #
  # Option source values stay opaque until this stage; functions receive
  # { scope = self } here so Home Manager option evaluation never resolves
  # renderer recursion.
  addRawContent =
    self:
    let
      selectedSources = normalizeSources self.sources;
    in
    {
      rawBlocks = lib.mapAttrs (_: applySource self) selectedSources.blocks;
      rawAgents = lib.mapAttrs (_: applySource self) selectedSources.agents;
      rawCommands = lib.mapAttrs (_: applySource self) selectedSources.commands;
      rawSkills = lib.mapAttrs (
        _: entry:
        let
          appliedEntry = applySource self entry;
        in
        appliedEntry
        // {
          main = applySource self appliedEntry.main;
        }
      ) selectedSources.skills;
      rawAuthoredInstructions = lib.mapAttrs (_: applySource self) selectedSources.instructions;
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
                    content = applySource self subData.content;
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

  # makeScope :: { harness, sources? } -> scope
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
    {
      harness,
      sources ? { },
    }:
    lib.fix (
      self:
      {
        inherit
          harness
          scopeApi
          sources
          ;

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
    normalizeSourceDeclarations
    injectCommandPreFlight
    addDualOutput
    addInstructions
    ;
}
