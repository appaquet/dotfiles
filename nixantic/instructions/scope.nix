{
  mkBlock,
  mkInstructions,
  mkAgent,
  mkSkill,
  mkSkillFile,
  mkCommand,
  forHarness,
  forSetting,
  renderFrontmatter,
  lib,
  pkgs,
}:

/*
  Scope pipeline — imports authored instruction sources, applies harness filtering,
  injects generated defaults, calls constructors, and assembles the final
  instruction map.

  Pipeline stages (makeScope):
    1. addRawContent        — normalize source inputs
    2. addProcessedContent  — filter by harness, inject defaults, call mk* constructors
    3. addDualOutput        — cross-artifact outputs (command→skill, skill→command)
    4. addInstructions      — assemble final instruction map, detect key collisions

  Each stage adds attrs to a lib.fix self-referencing record. Stages reference
  earlier stages via `self.raw*`, `self.agents`, `self.commands`, etc.
*/

let
  # makeScope :: { harness, sources? } -> scope
  #   Creates a harness-specific instruction scope by executing the 4-stage
  #   pipeline. The returned scope is a lib.fix self-referencing record
  #   containing all imported and processed instruction data for the given
  #   harness.
  makeScope =
    {
      harness,
      sources ? { },
      settings ? { },
    }:
    lib.fix (
      self:
      {
        inherit
          harness
          scopeApi
          sources
          settings
          ;

        forHarness = forHarness self;
        forSetting = forSetting self;
      }
      // addRawContent self
      // addProcessedContent self
      // addDualOutput self
      // addInstructions self
    );

  # scopeApi :: { mkBlock, mkInstructions, mkAgent, mkSkill, mkCommand, mkSkillFile, forHarness, forSetting, renderFrontmatter }
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
      forSetting
      renderFrontmatter
      ;
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
      selectedSources = ensureSourceDefaults self.sources;
      rawAgentMetadata = mkRawAgentMetadata selectedSources.agents;
      rawCommandMetadata = mkRawCommandMetadata selectedSources.commands;
      rawSkillMetadata = mkRawSkillMetadata selectedSources.skills self.rawCommands;
    in
    {
      rawBlocks = lib.mapAttrs (
        _: applySource self rawAgentMetadata rawCommandMetadata rawSkillMetadata
      ) selectedSources.blocks;
      rawAgents = lib.mapAttrs (
        _: applySource self rawAgentMetadata rawCommandMetadata rawSkillMetadata
      ) selectedSources.agents;
      rawCommands = lib.mapAttrs (
        _: applySource self rawAgentMetadata rawCommandMetadata rawSkillMetadata
      ) selectedSources.commands;
      rawSkills = lib.mapAttrs (
        key: entry:
        if !(builtins.isAttrs entry) || !(builtins.hasAttr "main" entry) then
          throw "Nixantic skill '${key}' must be an attrset with a main attribute"
        else
          entry
          // {
            main = applySource self rawAgentMetadata rawCommandMetadata rawSkillMetadata entry.main;
            files = entry.files or { };
          }
      ) selectedSources.skills;
      rawAuthoredInstructions = lib.mapAttrs (
        _: applySource self rawAgentMetadata rawCommandMetadata rawSkillMetadata
      ) selectedSources.instructions;
    };

  # Stage 2: Filter by harness, inject defaults, call constructors.
  #
  # Consumes: self.raw*
  # Produces:
  #   blocks     — all blocks → mkBlock (no filtering)
  #   agents     — filtered rawAgents → mkAgent(harness, name)
  #   commands   — filtered rawCommands → block-reference injection → mkCommand(harness, kind, outputPath, name)
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
        commandData = injectCommandBlockReferences self data;
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
                    content =
                      applySource self (mkRawAgentMetadata self.rawAgents) (mkRawCommandMetadata self.rawCommands)
                        (mkRawSkillMetadata self.rawSkills self.rawCommands)
                        subData.content;
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
  # Consumes: self.rawCommands, self.rawSkills, self.blocks (via injectCommandBlockReferences)
  # Produces:
  #   extraSkillsFromCommands — commands with asSkill flag → mkSkill(kind="directory")
  #   extraCommandsFromSkills — skills with asCommand flag → mkSkill(kind="flat")
  #
  # Dual-output flags (asSkill, asCommand) accept bool or per-harness attrsets,
  # resolved via isEnabledForHarness.
  addDualOutput = self: {
    extraSkillsFromCommands = lib.listToAttrs (
      builtins.concatLists (
        lib.mapAttrsToList (
          key: data:
          if data ? asSkill && isEnabledForHarness self data.asSkill then
            let
              skillName = data.name or key;
              commandData = injectCommandBlockReferences self data;
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
          if entry.main ? asCommand && isEnabledForHarness self entry.main.asCommand then
            let
              cmdName = entry.main.name or key;
              commandData = injectCommandBlockReferences self entry.main;
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

    # Detect any key declared by more than one instruction source generically,
    # rather than enumerating a hand-picked subset of source pairs. A key that
    # the final `//` merge would silently resolve is reported here instead.
    collisions =
      let
        instructionSources = [
          self.authoredInstructions
          self.agentInstructions
          self.commandInstructions
          self.extraCommandsFromSkills
          self.skillMainInstructions
          self.extraSkillsFromCommands
        ];
        keyCounts = builtins.foldl' (
          counts: source:
          builtins.foldl' (acc: key: acc // { ${key} = (acc.${key} or 0) + 1; }) counts (
            builtins.attrNames source
          )
        ) { } instructionSources;
      in
      builtins.filter (key: keyCounts.${key} > 1) (builtins.attrNames keyCounts);

    instructions =
      assert
        self.collisions == [ ]
        || throw "Generated instructions collide with authored instructions: ${builtins.concatStringsSep ", " self.collisions}";
      self.authoredInstructions
      // self.agentInstructions
      // self.commandInstructions
      // self.extraCommandsFromSkills
      // self.skillMainInstructions
      // self.extraSkillsFromCommands;
  };

  # ── Helpers ────────────────────────────────────────────────────────────────

  # isEnabledForHarness :: self -> val -> bool
  #   Resolves dual-output flags (asSkill, asCommand). Accepts a boolean or a
  #   per-harness attrset (e.g. { claude = true; opencode = false; }). For
  #   attrsets, selects the active harness key; absent = false.
  isEnabledForHarness =
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

  doesWhenPredicateMatch =
    self: kind: key: data:
    if !(builtins.hasAttr "when" data) then
      true
    else if !(builtins.isFunction data.when) then
      throw "Nixantic ${kind} '${key}' when predicate must be a function"
    else
      let
        result = data.when { scope = self; };
      in
      if builtins.isBool result then
        result
      else
        throw "Nixantic ${kind} '${key}' when predicate must return a boolean";

  isIncluded =
    self: kind: key: data:
    isForHarness self data && doesWhenPredicateMatch self kind key data;

  # filterForHarness :: self -> attrs -> attrs
  #   Filters an attrset by harness and declaration-level `when` predicates.
  filterForHarness = self: lib.filterAttrs (key: data: isIncluded self "source" key data);

  # filterSkillsForHarness :: self -> attrs -> attrs
  #   Same as filterForHarness but checks entry.main (skills use { main, files } structure).
  filterSkillsForHarness = self: lib.filterAttrs (key: entry: isIncluded self "skill" key entry.main);

  applySource =
    self: rawAgentMetadata: rawCommandMetadata: rawSkillMetadata: value:
    if builtins.isFunction value then
      value {
        scope = self // {
          agents = rawAgentMetadata;
          commands = rawCommandMetadata;
          skills = rawSkillMetadata;
          instructions = throw "Nixantic source functions must not reference final scope.instructions while raw sources are being normalized";
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

  sourceKindNames = builtins.attrNames emptySources;

  ensureSourceDefaults = sources: emptySources // sources;

  # mkRawAgentMetadata :: rawAgents -> { <agent-key> = { name, description, reference }; }
  #   Safe raw-phase agent surface for source functions. It intentionally uses
  #   only declaration keys and authored metadata, never rendered or processed
  #   agent content, so agent references can be reused without renderer cycles.
  mkRawAgentMetadata =
    rawAgents:
    lib.mapAttrs (
      key: data:
      let
        isAttrDeclaration = builtins.isAttrs data;
        name = if isAttrDeclaration && builtins.hasAttr "name" data then data.name else key;
        description =
          if isAttrDeclaration && builtins.hasAttr "description" data then
            data.description
          else
            throw "Nixantic raw agent metadata for '${key}' requires an authored description";
      in
      {
        inherit name description;
        reference = "(See agent: ${name})";
      }
    ) rawAgents;

  # mkRawCommandMetadata :: rawCommands -> { <command-key> = { name, reference }; }
  #   Safe raw-phase command surface for source functions. It intentionally uses
  #   only declaration keys and authored names, never processed command content,
  #   so command references can fail on rename without creating renderer cycles.
  mkRawCommandMetadata =
    rawCommands:
    lib.mapAttrs (
      key: data:
      let
        name = if builtins.isAttrs data && builtins.hasAttr "name" data then data.name else key;
      in
      {
        inherit name;
        reference = "(See command: ${name})";
      }
    ) rawCommands;

  # mkRawSkillMetadata :: rawSkills -> rawCommands -> { <skill-key> = { name, reference }; }
  #   Safe raw-phase skill surface for source functions. It intentionally exposes
  #   only stable pointer metadata for directory-declared skills and commands
  #   marked with asSkill, avoiding rendered bodies or processed skill values.
  mkRawSkillMetadata =
    rawSkills: rawCommands:
    let
      directorySkillMetadata = lib.mapAttrs (key: _: mkRawSkillReference key) rawSkills;

      commandSkillMetadata = lib.listToAttrs (
        builtins.concatLists (
          lib.mapAttrsToList (
            key: data:
            if builtins.isAttrs data && isRawAsSkillDeclared data then
              let
                name = if builtins.hasAttr "name" data then data.name else key;
              in
              [
                {
                  inherit name;
                  value = mkRawSkillReference name;
                }
              ]
            else
              [ ]
          ) rawCommands
        )
      );
    in
    directorySkillMetadata // commandSkillMetadata;

  mkRawSkillReference = name: {
    inherit name;
    reference = "(See skill: ${name})";
  };

  isRawAsSkillDeclared =
    data:
    let
      asSkill = data.asSkill;
    in
    if !(builtins.hasAttr "asSkill" data) then
      false
    else if builtins.isBool asSkill then
      asSkill
    else if builtins.isAttrs asSkill then
      builtins.any (harness: asSkill.${harness} or false) (builtins.attrNames asSkill)
    else
      false;

  # normalizeSourceDeclarations :: sourceOwners -> { sources }
  #   Flattens owner-keyed source declarations into flat per-kind maps
  #   (`{ blocks, agents, commands, skills, instructions }`). The no-duplicate-key
  #   invariant is enforced upstream in source-sets.nix `resolveSources`,
  #   where file-path origins make for the richest diagnostics; this function
  #   trusts pre-validated input and only reshapes it.
  normalizeSourceDeclarations =
    sourceOwners:
    let
      owners = builtins.attrNames sourceOwners;

      flattenedFor =
        kind: builtins.foldl' (acc: owner: acc // (sourceOwners.${owner}.${kind} or { })) { } owners;
    in
    {
      sources = lib.genAttrs sourceKindNames flattenedFor;
    };

  # defaultCommandBlockReferences :: self -> [ string ]
  #   Source blocks may opt into default command reference injection with
  #   injectReferenceIntoCommands = true. Reusable consumers that do not declare
  #   such a block get no implicit command content.
  defaultCommandBlockReferences =
    self:
    map (blockName: self.blocks.${blockName}.reference) (
      builtins.filter (blockName: self.blocks.${blockName}.injectReferenceIntoCommands or false) (
        builtins.attrNames self.blocks
      )
    );

  # requestedCommandBlockReferences :: self -> data -> [ string ]
  #   When onlyInjectBlockReferences is present, it is a replacement list of
  #   block names whose references are injected in authored order. When absent,
  #   defaults come from blocks that opted into command reference injection.
  requestedCommandBlockReferences =
    self: data:
    if builtins.hasAttr "onlyInjectBlockReferences" data then
      let
        requestedNames = data.onlyInjectBlockReferences;
        duplicateNames = builtins.filter (name: countOccurrences name requestedNames > 1) (
          lib.unique requestedNames
        );
      in
      if duplicateNames != [ ] then
        throw "onlyInjectBlockReferences contains duplicate block names: ${builtins.concatStringsSep ", " duplicateNames}"
      else
        map (blockName: self.blocks.${blockName}.reference) requestedNames
    else
      defaultCommandBlockReferences self;

  # injectCommandBlockReferences :: self -> data -> data
  #   Appends selected block references to command content. Consumed by
  #   addProcessedContent and addDualOutput.
  injectCommandBlockReferences =
    self: data:
    let
      references = builtins.filter (reference: reference != "") (
        requestedCommandBlockReferences self data
      );
    in
    if references == [ ] then
      data
    else
      data
      // {
        content = "${data.content}\n\n${builtins.concatStringsSep "\n\n" references}";
      };

  countOccurrences =
    needle: values: builtins.length (builtins.filter (value: value == needle) values);
in
{
  inherit
    scopeApi
    makeScope
    normalizeSourceDeclarations
    injectCommandBlockReferences
    addDualOutput
    addInstructions
    ;
}
