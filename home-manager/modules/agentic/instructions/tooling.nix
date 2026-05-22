{ pkgs, lib }:

let
  frontmatter = import ./frontmatter.nix;

  mkBlock =
    {
      heading ? null,
      content,
      tag ? null,
      taggedContent ? null,
      ...
    }@extra:
    let
      inner = if taggedContent != null then taggedContent else content;
      body = if tag != null then "${content}\n<${tag}>\n${inner}</${tag}>" else content;
    in
    rec {
      inherit heading content;

      embed = if heading != null then "## ${heading}\n\n${body}" else body;

      reference =
        if tag != null then
          "See <${tag}>"
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

  mkAgent =
    {
      name,
      description,
      model ? { },
      content,
      harness,
      ...
    }:
    let
      m = model.${harness.name} or harness.defaultModel;
      frontmatter = harness.renderAgentFrontmatter {
        inherit name description;
        model = m;
      };
    in
    {
      embed = "${frontmatter}\n${content}";
      reference = "(See agent: ${name})";
    };

  mkSkill =
    {
      name,
      description,
      content,
      harness,
      kind ? "flat",
      outputPath ? null,
      argumentHint ? null,
      model ? { },
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
      m = if model != { } then model.${harness.name} or harness.defaultModel else null;
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
      outputPath = if outputPath != null then outputPath else null;
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

  forHarness =
    scope: values:
    values.${scope.harness.name} or (
      if builtins.hasAttr "default" values then
        values.default
      else
        throw "Unsupported harness: ${scope.harness.name}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames values)}"
    );

  renderFrontmatter = frontmatter.renderFrontmatter;

  mkCommand = mkSkill;

  api = {
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

  importDir =
    {
      dir,
      args,
      recursive ? false,
    }:
    let
      inherit (builtins)
        readDir
        attrNames
        match
        listToAttrs
        concatMap
        ;

      flat =
        d:
        let
          entries = readDir d;
        in
        listToAttrs (
          builtins.filter (x: x != null) (
            map (
              name:
              let
                m = match "(.*)\\.nix" name;
              in
              if m != null && name != "default.nix" && entries.${name} == "regular" then
                {
                  name = builtins.head m;
                  value = import (d + "/${name}") args;
                }
              else
                null
            ) (attrNames entries)
          )
        );

      recurse =
        d: prefix:
        let
          entries = readDir d;
        in
        concatMap (
          name:
          let
            type = entries.${name};
          in
          if type == "directory" then
            recurse (d + "/${name}") (if prefix == "" then name else "${prefix}/${name}")
          else
            let
              m = match "(.*)\\.nix" name;
            in
            if m != null && name != "default.nix" && type == "regular" then
              let
                base = builtins.head m;
                key = if prefix == "" then base else "${prefix}/${base}";
              in
              [
                {
                  name = key;
                  value = import (d + "/${name}") args;
                }
              ]
            else
              [ ]
        ) (attrNames entries);
    in
    if recursive then listToAttrs (recurse dir "") else flat dir;

  importSkillsDir =
    {
      dir,
      args,
    }:
    let
      inherit (builtins)
        attrNames
        concatLists
        listToAttrs
        match
        pathExists
        readDir
        ;

      entries = readDir dir;

      subdirs = builtins.filter (n: entries.${n} == "directory") (attrNames entries);

      collectSubFiles =
        d: args:
        let
          subs = readDir d;
        in
        listToAttrs (
          concatLists (
            map (
              name:
              let
                fullPath = d + "/${name}";
              in
              if subs.${name} == "regular" then
                if match ".*\\.md" name != null then
                  [
                    {
                      inherit name;
                      value = {
                        kind = "md";
                        content = builtins.readFile fullPath;
                      };
                    }
                  ]
                else if match ".*\\.nix" name != null && name != "default.nix" then
                  [
                    {
                      inherit name;
                      value = {
                        kind = "nix";
                        content = import fullPath args;
                      };
                    }
                  ]
                else
                  [ ]
              else if subs.${name} == "directory" then
                let
                  nested = collectSubFiles fullPath args;
                in
                map
                  (nv: {
                    name = "${name}/${nv.name}";
                    value = nv.value;
                  })
                  (
                    lib.mapAttrsToList (n: v: {
                      name = n;
                      value = v;
                    }) nested
                  )
              else
                [ ]
            ) (attrNames subs)
          )
        );

    in
    listToAttrs (
      map (
        n:
        let
          d = dir + "/${n}";
        in
        if pathExists (d + "/default.nix") then
          {
            name = n;
            value = {
              kind = "directory";
              main = import (d + "/default.nix") args;
              files = collectSubFiles d args;
            };
          }
        else
          throw "Skills directory '${n}' has no default.nix"
      ) subdirs
    );

  makeScope =
    harness:
    lib.fix (
      self:
      let
        rawAuthoredInstructions = importDir {
          dir = ./instructions;
          args = {
            scope = self;
          };
          recursive = true;
        };
      in
      {
        inherit harness api;

        forHarness = forHarness self;

        rawBlocks = importDir {
          dir = ./blocks;
          args = {
            scope = self;
          };
        };

        blocks = lib.mapAttrs (_: data: self.api.mkBlock data) self.rawBlocks;

        rawAgents = importDir {
          dir = ./agents;
          args = {
            scope = self;
          };
        };

        agents = lib.mapAttrs (
          key: data:
          self.api.mkAgent (
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
          self.api.mkCommand (
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

        rawSkills = importSkillsDir {
          dir = ./skills;
          args = {
            scope = self;
          };
        };

        skills = lib.mapAttrs (
          key: entry:
          self.api.mkSkill (
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

        authoredInstructions = lib.mapAttrs (_: data: self.api.mkInstructions data) (
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
                      self.api.mkSkillFile {
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
          ++ builtins.attrNames (lib.intersectAttrs self.authoredInstructions self.skillMainInstructions);

        instructions =
          assert
            self.collisions == [ ]
            || builtins.throw "Generated instructions collide with authored instructions: ${builtins.concatStringsSep ", " self.collisions}";
          self.authoredInstructions
          // self.agentInstructions
          // self.commandInstructions
          // self.skillMainInstructions;
      }
    );

  postProcessContent =
    text:
    let
      lines = lib.splitString "\n" text;
      stripTrailingPeriod =
        line:
        let
          m = builtins.match "(.*)\\.$" line;
        in
        if m != null then builtins.head m else line;
      stripped = map stripTrailingPeriod lines;
      nonEmpty = builtins.filter (line: null == builtins.match "^[[:space:]]*$" line) stripped;
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
    api
    importDir
    importSkillsDir
    makeScope
    mkFile
    mkPackage
    ;
}
