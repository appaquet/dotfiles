{ pkgs, lib }:

let
  frontmatter = import ./frontmatter.nix;

  # mkInstructions :: { heading, content, outputPath?, harnesses?, ... }
  #   Authored instruction files (CLAUDE.md, AGENTS.md, rule files).
  #   Source: nixantic.sources.<source-owner>.instructions.*, keyed by output key.
  #
  #   Required
  #     heading    - Top-level heading. Emitted as `# heading`; used as reference label.
  #     content    - Instruction body, appended after the heading.
  #
  #   Optional
  #     outputPath - Output filename override. Defaults to `<instruction-key>.md`.
  #
  #   Scope-consumed
  #     harnesses  - Restrict to specific harnesses. Omitted = all harnesses.
  #
  #   Returns: { outputPath, embed, reference }
  mkInstructions = args: {
    outputPath = args.outputPath or null;
    embed = "# ${args.heading}\n\n${args.content}";
    reference = "(See: ${args.heading})";
  };

  # mkAgent :: { harness, name, description, content, model?, effort?, permission?, harnesses?, ... }
  #   AI agent definitions.
  #   Source: nixantic.sources.<source-owner>.agents.*, keyed by artifact key.
  #
  #   Required
  #     content      - Agent instruction body, placed after frontmatter.
  #     description  - Frontmatter description.
  #
  #   Optional (authored)
  #     name         - Display name. Defaults to filename stem.
  #     model        - Attrset keyed by harness name (e.g. { claude = "sonnet"; }).
  #                    Constructor selects model.<active-harness> or null.
  #     effort       - Thinking/reasoning effort level. Can be:
  #                    - String: same value for all harnesses (e.g. "high")
  #                    - Attrset: keyed by harness name (e.g. { claude = "max"; opencode = "xhigh"; })
  #                    Constructor selects effort.<active-harness> or uses the string as-is.
  #                    Harness-rendered: Claude renders as `effort`; OpenCode renders as `reasoningEffort`.
  #     permission   - Attrset keyed by harness name (e.g. { claude = { disallowedTools = [ "Agent" ]; }; }).
  #                    Constructor selects permission.<active-harness> or null.
  #
  #   Scope-consumed
  #     harnesses    - Restrict to specific harnesses. Omitted = all harnesses.
  #
  #   Scope-injected (authors do not set)
  #     harness      - Active harness renderer.
  #     name         - Effective name (authored name or filename stem).
  #
  #   Returns: { embed, reference }
  mkAgent =
    args:
    let
      model = args.model or null;
      selectedModel = if model != null then model.${args.harness.name} or null else null;
      effort = args.effort or null;
      selectedEffort =
        if effort != null then
          if builtins.isAttrs effort then effort.${args.harness.name} or null else effort
        else
          null;
      permission = args.permission or null;
      selectedPermission = if permission != null then permission.${args.harness.name} or null else null;
      frontmatter = args.harness.renderAgentFrontmatter {
        inherit (args) name description;
        model = selectedModel;
        effort = selectedEffort;
        permission = selectedPermission;
      };
    in
    {
      embed = "${frontmatter}\n${args.content}";
      reference = "(See agent: ${args.name})";
    };

  # mkSkill :: { harness, name, description, content, kind?, outputPath?, model?, harnesses?,
  # asCommand?, argumentHint?, metadata?, effort?, context?, agent?, allowedTools?, whenToUse?,
  # disableModelInvocation?, userInvocable?, subtask?, ... }
  #   Skill and command definitions. Used for directory skills and internally for
  #   command↔skill dual output.
  #   Source: nixantic.sources.<source-owner>.skills.*; also used by scope for
  #     command-derived skills and skill-derived commands.
  #
  #   Required
  #     content      - Body text, placed after frontmatter.
  #     description  - Frontmatter description.
  #
  #   Optional (authored)
  #     name         - Display name. Defaults to directory name (skills) or
  #                    filename stem (commands).
  #     model        - Attrset keyed by harness name. Selects model.<active-harness>
  #                    or null.
  #
  #   Frontmatter — skill (kind="directory"):
  #     Both harnesses:  name, description, metadata
  #     Claude only:     model, argumentHint, effort, context, agent, allowedTools,
  #                      whenToUse, disableModelInvocation, userInvocable
  #     Opencode only:   —
  #
  #   Frontmatter — command (kind="flat"):
  #     Both harnesses:  description, model, agent
  #     Claude only:     name, argumentHint, effort, context, allowedTools
  #     Opencode only:   subtask
  #
  #   Scope-consumed
  #     harnesses    - Restrict to specific harnesses. Omitted = all harnesses.
  #     asCommand    - bool | { <harness> = bool; }. When enabled, creates a
  #                    companion command output from a directory skill.
  #
  #   Scope-injected (authors do not set)
  #     harness      - Active harness renderer.
  #     kind         - "directory" (skill) or "flat" (command).
  #     outputPath   - Rendered file path.
  #
  #   Returns: { embed, reference, outputPath }
  mkSkill =
    args:
    let
      kind = args.kind or "flat";
      model = args.model or null;
      selectedModel = if model != null then model.${args.harness.name} or null else null;
      optional = name: args.${name} or null;
      frontmatter =
        if kind == "directory" then
          args.harness.renderSkillFrontmatter {
            inherit (args) name description;
            argumentHint = optional "argumentHint";
            metadata = optional "metadata";
            effort = optional "effort";
            context = optional "context";
            agent = optional "agent";
            allowedTools = optional "allowedTools";
            whenToUse = optional "whenToUse";
            disableModelInvocation = optional "disableModelInvocation";
            userInvocable = optional "userInvocable";
            model = selectedModel;
          }
        else
          args.harness.renderCommandFrontmatter {
            inherit (args) name description;
            argumentHint = optional "argumentHint";
            effort = optional "effort";
            context = optional "context";
            agent = optional "agent";
            allowedTools = optional "allowedTools";
            subtask = optional "subtask";
            model = selectedModel;
          };
    in
    {
      embed = "${frontmatter}\n${args.content}";
      reference = "(See ${if kind == "directory" then "skill" else "command"}: ${args.name})";
      outputPath = args.outputPath or null;
    };

  # mkSkillFile :: { content, outputPath?, ... }
  #   Sub-files within a skill directory.
  #   Source: nixantic.sources.<source-owner>.skills.<skill>.files.*.
  #     .nix sub-files are imported with { scope }; .md sub-files bypass this
  #     constructor and are copied raw.
  #
  #   Required
  #     content      - Sub-file body text.
  #
  #   Scope-injected (authors do not set)
  #     outputPath   - Rendered file path (skills/<directory>/<relative-subpath>).
  #
  #   Scope behavior
  #     Sub-files are included only when the parent skill passes harness filtering.
  #     No per-sub-file harness filtering is supported.
  #
  #   Returns: { outputPath, embed }
  mkSkillFile = args: {
    outputPath = args.outputPath or null;
    embed = args.content;
  };

  # mkCommand :: { harness, name, description, content, kind?, outputPath?, model?, harnesses?, asSkill?, onlyInjectBlockReferences?, argumentHint?, effort?, context?, agent?, allowedTools?, subtask?, ... }
  #   Slash-command definitions. Delegates to mkSkill with kind="flat".
  #   Source: nixantic.sources.<source-owner>.commands.*, keyed by artifact key.
  #
  #   Required
  #     content      - Command body text. Scope appends references for blocks with
  #                    injectReferenceIntoCommands = true before constructor call unless replaced.
  #     description  - Frontmatter description.
  #
  #   Optional (authored)
  #     name         - Display name. Defaults to filename stem.
  #     model        - Attrset keyed by harness name. Selects model.<active-harness>
  #                    or null.
  #
  #   Frontmatter (command, kind="flat"):
  #     Both harnesses:  description, model, agent
  #     Claude only:     name, argumentHint, effort, context, allowedTools
  #     Opencode only:   subtask
  #
  #   Scope-consumed
  #     harnesses        - Restrict to specific harnesses. Omitted = all harnesses.
  #     asSkill          - bool | { <harness> = bool; }. When enabled, creates a
  #                        companion skill output.
  #     onlyInjectBlockReferences - Optional replacement list of block keys whose references are injected.
  #
  #   Scope-injected (authors do not set)
  #     harness      - Active harness renderer.
  #     kind         - "flat".
  #     outputPath   - Rendered file path (commands/<name>.md).
  #
  #   Returns: { embed, reference, outputPath }
  mkCommand =
    args:
    let
      name = args.name or (throw "mkCommand requires name");
    in
    mkSkill (
      {
        kind = "flat";
        outputPath = "commands/${name}.md";
      }
      // args
      // {
        inherit name;
      }
    );

  # mkBlock :: { heading?, content, tag?, taggedContent?, ... }
  #   Reusable content blocks available in every harness scope.
  #   Source: nixantic.sources.<source-owner>.blocks.*, keyed by source key.
  #
  #   Required
  #     content        - Block body text.
  #
  #   Optional
  #     heading        - Section title. Embed emits `## heading`; reference emits
  #                      `(See: heading)`.
  #     tag            - XML tag name. Wraps taggedContent; reference emits `<tag>`.
  #     taggedContent  - XML tag body. Requires `tag`; replaces `content`
  #                      inside the XML wrapper.
  #
  #   Scope behavior
  #     No harness filtering. Blocks are always included, regardless of harness.
  #
  #   Returns: { heading, content, body, embed, reference, ... } (extra attrs pass through)
  #     body      - Heading-less block body (the tag-wrapped content when `tag` is
  #                 set, otherwise raw content). Use this when a consumer needs the
  #                 body without the `## heading` prefix that `embed` adds.
  #     embed     - Full inline body, prefixed with `## heading` when a heading is set.
  #     reference - Pointer form: `<tag>` when tagged, `(See: heading)` when a heading
  #                 is set, otherwise empty.
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
      body =
        if taggedContent != null && tag == null then
          throw "mkBlock: taggedContent requires tag"
        else if tag != null then
          "${content}\n<${tag}>\n${inner}</${tag}>"
        else
          content;
    in
    rec {
      inherit heading content body;
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

  # forHarness :: scope -> { <harness-name>?, default?, ... } -> value
  #   scope: active instruction scope containing harness.name
  #   <harness-name>: value selected when key matches the active harness
  #   default: fallback value when the active harness key is absent - optional
  #   ...: other harness-specific values; ignored unless selected
  #   Returns: selected harness-specific value or throws for unsupported harnesses
  forHarness =
    scope: values:
    values.${scope.harness.name} or (
      if builtins.hasAttr "default" values then
        values.default
      else
        throw "Unsupported harness: ${scope.harness.name}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames values)}"
    );

  # forSetting :: scope -> string|[string] -> { <setting-value>?, default?, ... } -> value
  #   Selects authored content from structured scope.settings. The path may be a
  #   dot-separated string such as "versionControl.mode" or a list of attr names.
  forSetting =
    scope: path: values:
    let
      pathParts = if builtins.isList path then path else lib.splitString "." path;
      settingValue = lib.getAttrFromPath pathParts scope.settings;
    in
    values.${settingValue} or (
      if builtins.hasAttr "default" values then
        values.default
      else
        throw "Unsupported setting ${builtins.concatStringsSep "." pathParts}: ${settingValue}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames values)}"
    );

  renderFrontmatter = frontmatter.renderFrontmatter;

  scopeMod = import ./scope.nix {
    inherit
      mkBlock
      mkInstructions
      mkAgent
      mkSkill
      mkSkillFile
      mkCommand
      forHarness
      forSetting
      renderFrontmatter
      pkgs
      lib
      ;
  };

  outputMod = import ./output.nix { inherit pkgs lib; };
in
{
  inherit (scopeMod)
    scopeApi
    makeScope
    normalizeSourceDeclarations
    injectCommandBlockReferences
    addDualOutput
    addInstructions
    ;
  inherit (outputMod)
    postProcessContent
    mkFile
    mkPackage
    ;
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
}
