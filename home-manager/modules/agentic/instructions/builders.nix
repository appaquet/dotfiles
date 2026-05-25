{ pkgs, lib }:

/*
  Nix template-to-markdown generator for AI agent instructions (Claude + Opencode).

  Data flow:
    Harness definitions (claude.nix / opencode.nix) define platform-specific frontmatter rendering
      → makeScope (lib.fix recursive attrset binding harness + content)
      → mkPackage (symlinkJoin of all generated .md files)

  Key concepts:
    Harness - A platform adapter providing name, outputDir, tools, and three frontmatter
              renderers (renderAgentFrontmatter, renderCommandFrontmatter,
              renderSkillFrontmatter). See harnesses/default.nix for the full contract.
    Scope   - A recursive attrset (via lib.fix) binding harness + scopeApi + all content
              (blocks, agents, commands, skills, instructions). Content files receive `{ scope }`
              and return plain data attrsets; makeScope interposes with constructors centrally.
    Block   - A reusable instruction fragment. Returns `{ embed, reference }` where embed is
              the rendered markdown string and reference is an inline link/citation.
*/
# REVIEW: architecture-reviewer - `builders.nix` is 549 lines with multiple distinct concerns:
# constructors (mkBlock, mkSkill, mkAgent, etc.), scope building (makeScope with import+transform
# logic), post-processing (postProcessContent), file writing (mkFile), and package building
# (mkPackage). Each concern maps to a different architectural layer. Consider extracting:
# - `constructors.nix` — mkBlock, mkInstructions, mkAgent, mkSkill, mkCommand, mkSkillFile
# - `scope.nix` — makeScope with import mappings, dual-output logic, collision detection
# - `output.nix` — postProcessContent, mkFile, mkPackage
# This would keep each file under ~200 lines with single-responsibility focus, improving testability
# and reducing cognitive load when reasoning about scope-building vs. output-rendering concerns.

let
  frontmatter = import ./frontmatter.nix;
  files = import ./files.nix { inherit pkgs lib; };

  /*
    Wraps authored content into `{ embed, reference }` with optional ## heading and XML tag.
    When `tag` is set, wraps `taggedContent` in `<tag>...</tag>` after the main content.
  */
  mkBlock =
    {
      heading ? null,
      content,
      tag ? null,
      taggedContent ? null,
      ...
    }@extra:
    let
      inner =
        if taggedContent != null then
          taggedContent
        else if tag != null then
          throw "mkBlock: taggedContent required when tag is set"
        else
          content;
      body = if tag != null then "${content}\n<${tag}>\n${inner}</${tag}>" else content;
    in
    rec {
      inherit heading content;

      embed = if heading != null then "## ${heading}\n\n${body}" else body;

      reference =
        if tag != null then
          "<${tag}>"
        else if heading != null then
          "(See: ${heading})"
        else
          "";
    }
    // extra;

  mkInstructions =
    {
      heading,
      content,
      outputPath ? null,
      ...
    }:
    {
      inherit outputPath;

      embed = "# ${heading}\n\n${content}";
      reference = "(See: ${heading})";
    };

  /*
    Wraps authored content into `{ embed, reference }` with harness-rendered agent frontmatter
    (name, description, model). Calls `harness.renderAgentFrontmatter`.
  */
  mkAgent =
    {
      name,
      description,
      model ? null,
      content,
      harness,
      ...
    }:
    let
      m = if model != null then model.${harness.name} or null else null;
      frontmatter = harness.renderAgentFrontmatter {
        inherit name description;
        model = m;
      };
    in
    {
      embed = "${frontmatter}\n${content}";
      reference = "(See agent: ${name})";
    };

  /*
    Wraps authored content into `{ embed, reference, outputPath? }` with harness-rendered
    frontmatter. Supports `kind = "directory"` (skills) and `kind = "flat"` (commands) frontmatter
    via harness renderers.
  */
  mkSkill =
    {
      name,
      description,
      content,
      harness,
      kind ? "flat",
      asSkill ? (kind == "directory"),
      asCommand ? (kind == "flat"),
      outputPath ? null,
      argumentHint ? null,
      model ? null,
      effort ? null,
      context ? null,
      agent ? null,
      allowedTools ? null,
      subtask ? null,
      license ? null,
      compatibility ? null,
      metadata ? null,
      whenToUse ? null,
      disableModelInvocation ? null,
      userInvocable ? null,
      ...
    }:
    let
      m = if model != null then model.${harness.name} or null else null;
      frontmatter =
        if kind == "directory" then
          harness.renderSkillFrontmatter {
            inherit
              name
              description
              argumentHint
              license
              compatibility
              metadata
              effort
              context
              agent
              allowedTools
              whenToUse
              disableModelInvocation
              userInvocable
              ;
            model = m;
          }
        else
          harness.renderCommandFrontmatter {
            inherit
              name
              description
              argumentHint
              effort
              context
              agent
              allowedTools
              subtask
              ;
            model = m;
          };
    in
    {
      embed = "${frontmatter}\n${content}";
      reference = "(See ${if kind == "directory" then "skill" else "command"}: ${name})";
      inherit outputPath;
    };

  mkSkillFile =
    {
      content,
      outputPath ? null,
      ...
    }:
    {
      inherit outputPath;
      embed = content;
    };

  /*
    Thin wrapper around mkSkill. Pre-sets `kind = "flat"` and
    `outputPath = "commands/${name}.md"`. Callers can override defaults by passing explicit
    fields.
  */
  mkCommand =
    args:
    let
      attrs = {
        kind = "flat";
        outputPath = "commands/${args.name or (throw "mkCommand requires name")}.md";
      }
      // args;
    in
    mkSkill attrs;

  /*
    Dispatches on `scope.harness.name`, returning `values.<harness>` or `values.default` if
    harness not found. Throws with available keys otherwise.
  */
  forHarness =
    scope: values:
    values.${scope.harness.name} or (
      if builtins.hasAttr "default" values then
        values.default
      else
        throw "Unsupported harness: ${scope.harness.name}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames values)}"
    );

  renderFrontmatter = frontmatter.renderFrontmatter;

  /*
    Tool bundle injected into the recursive scope. Content authors access these via
    `scope.scopeApi.mkBlock`, `scope.scopeApi.mkInstructions`, etc.
  */
  scopeApi = {
    inherit
      mkBlock
      mkInstructions
      mkAgent
      mkSkill
      mkCommand
      mkSkillFile
      importSkillsDir
      forHarness
      renderFrontmatter
      ;
  };

  importDir = files.importDir;
  importSkillsDir = files.importSkillsDir;

  # REVIEW: code-style-reviewer - `makeScope` is ~225 lines long and contains multiple logical sections: raw content loading, content processing (agents, commands, skills), dual-output generation, instruction assembly, collision detection, and output merging. Per guidelines: "Functions are short, focused, do one thing well". Consider extracting `addRawContent`, `addProcessedContent`, `addDualOutput`, and `addInstructions` sub-functions to keep `makeScope` focused on orchestration.
  /*
    Builds a per-harness recursive attrset via lib.fix. Returns
    `{ harness, scopeApi, blocks, rawBlocks, agents, rawAgents, commands, rawCommands, skills,
    rawSkills, authoredInstructions, agentInstructions, commandInstructions,
    skillMainInstructions, skillFiles, collisions, instructions }`. Content files reference each
    other through scope (e.g., `scope.blocks.deep-thinking.embed`).
  */
  makeScope =
    harness:
    lib.fix (
      self:
      let
        isEnabledFor =
          val:
          if builtins.isBool val then
            val
          else if builtins.isAttrs val then
            val.${self.harness.name} or false
          else
            false;

        rawAuthoredInstructions = importDir {
          dir = ./instructions;
          args = {
            scope = self;
          };
          recursive = true;
        };
      in
      {
        inherit harness scopeApi;

        forHarness = forHarness self;

        rawBlocks = importDir {
          dir = ./blocks;
          args = {
            scope = self;
          };
        };

        blocks = lib.mapAttrs (_: data: self.scopeApi.mkBlock data) self.rawBlocks;

        rawAgents = importDir {
          dir = ./agents;
          args = {
            scope = self;
          };
        };

        agents = lib.mapAttrs (
          key: data:
          self.scopeApi.mkAgent (
            {
              harness = self.harness;
            }
            // data
            // {
              name = data.name or key;
            }
          )
        ) self.rawAgents;

        rawCommands = importDir {
          dir = ./commands;
          args = {
            scope = self;
          };
        };

        commands = lib.mapAttrs (
          key: data:
          self.scopeApi.mkCommand (
            {
              harness = self.harness;
              kind = "flat";
              outputPath = "commands/${data.name or key}.md";
            }
            // data
            // {
              name = data.name or key;
            }
          )
        ) self.rawCommands;

        extraSkillsFromCommands = lib.listToAttrs (
          builtins.concatLists (
            lib.mapAttrsToList (
              key: data:
              if data ? asSkill && isEnabledFor data.asSkill then
                let
                  skillName = data.name or key;
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
                      // data
                      // {
                        name = skillName;
                      }
                    );
                  }
                ]
              else
                [ ]
            ) self.rawCommands
          )
        );

        rawSkills = importSkillsDir {
          dir = ./skills;
          args = {
            scope = self;
          };
        };

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
        ) self.rawSkills;

        extraCommandsFromSkills = lib.listToAttrs (
          builtins.concatLists (
            lib.mapAttrsToList (
              key: entry:
              if entry.main ? asCommand && isEnabledFor entry.main.asCommand then
                let
                  cmdName = entry.main.name or key;
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
                      // entry.main
                      // {
                        name = cmdName;
                      }
                    );
                  }
                ]
              else
                [ ]
            ) self.rawSkills
          )
        );

        authoredInstructions = lib.mapAttrs (_: data: self.scopeApi.mkInstructions data) (
          lib.filterAttrs (
            _: data: !builtins.hasAttr "harnesses" data || builtins.elem self.harness.name data.harnesses
          ) rawAuthoredInstructions
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
            ) self.rawSkills
          )
        );

        collisions =
          builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.agentInstructions)
          ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.commandInstructions)
          ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.skillMainInstructions)
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
      }
    );

  # Removes blank lines and lone period sentinel lines from generated markdown.
  postProcessContent =
    text:
    let
      nonEmpty = builtins.filter (line: line != "." && null == builtins.match "^[[:space:]]*$" line) (
        lib.splitString "\n" text
      );
    in
    builtins.concatStringsSep "\n" nonEmpty;

  mkFile =
    dir: path: filename: content:
    pkgs.writeTextFile {
      name = builtins.replaceStrings [ "/" ] [ "-" ] "${dir}-${path}";
      text = content;
      destination = "/${dir}/${filename}";
    };

  mkPackage =
    {
      scopes,
      postProcess ? false,
    }:
    let
      process = if postProcess then postProcessContent else (x: x);
      allFiles = lib.concatLists (
        lib.mapAttrsToList (
          _: scope:
          (lib.mapAttrsToList (
            path: instr:
            let
              filename =
                if instr ? outputPath && instr.outputPath != null then instr.outputPath else "${path}.md";
            in
            mkFile scope.harness.outputDir path filename (process instr.embed)
          ) scope.instructions)
          ++ (lib.mapAttrsToList (
            path: f:
            let
              filename = if f ? outputPath && f.outputPath != null then f.outputPath else "${path}.md";
            in
            mkFile scope.harness.outputDir path filename (process f.embed)
          ) (scope.skillFiles or { }))
        ) scopes
      );
    in
    pkgs.symlinkJoin {
      name = "agentic-instructions";
      paths = allFiles;
    };
in
{
  inherit
    mkBlock
    mkInstructions
    mkAgent
    mkSkill
    mkCommand
    mkSkillFile
    postProcessContent
    forHarness
    renderFrontmatter
    scopeApi
    importDir
    importSkillsDir
    makeScope
    mkFile
    mkPackage
    ;
}
