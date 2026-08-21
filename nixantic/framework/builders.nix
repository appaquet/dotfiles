{ pkgs, lib }:

let
  frontmatter = import ./frontmatter.nix;
  artifact = import ./artifact.nix {
    inherit lib;
    inherit (frontmatter) renderFrontmatter;
  };

  renderArtifact =
    args:
    artifact.renderArtifact args.harness (
      {
        role = null;
        authoredOutputPath = null;
        description = null;
        model = null;
        effort = null;
        permission = null;
        argumentHint = null;
        metadata = null;
        context = null;
        agent = null;
        allowedTools = null;
        whenToUse = null;
        disableModelInvocation = null;
        userInvocable = null;
        subtask = null;
        skillKey = null;
        subPath = null;
      }
      // args
    );

  # mkReference :: string -> string -> string
  #   Formats a leading-article reference to an invocable instruction artifact.
  mkReference = kind: name: "the `${name}` ${kind}";

  # mkAgentReference :: string -> string
  #   Formats an agent reference that flows mid-sentence, without a leading
  #   article so it composes with surrounding prose (for example "a `X` agent").
  mkAgentReference = name: "`${name}` agent";

  # mkInstructions :: { heading, content, role?, outputPath?, harnesses?, ... }
  #   Authored instruction files (CLAUDE.md, AGENTS.md, rule files).
  #   Source: nixantic.sources.<source-owner>.instructions.*, keyed by logical name.
  #
  #   Required
  #     heading    - Top-level heading. Emitted as `# heading`; used as reference label.
  #     content    - Instruction body, appended after the heading.
  #
  #   Optional
  #     role       - "main", "rule", or "regular". Defaults to "regular" and
  #                  selects the renderer's semantic default destination.
  #     outputPath - Output filename override, which takes precedence over role defaults.
  #
  #   Scope-consumed
  #     harnesses  - Restrict to specific harnesses. Omitted = all harnesses.
  #
  #   Returns: { kind, role, outputPath, embed, reference }
  mkInstructions =
    args:
    let
      role = args.role or "regular";
    in
    assert
      builtins.elem role [
        "main"
        "rule"
        "regular"
      ]
      || throw "Nixantic instruction role must be main, rule, or regular";
    renderArtifact {
      inherit (args) harness key;
      kind = "instruction";
      inherit role;
      content = "# ${args.heading}\n\n${args.content}";
      authoredOutputPath = args.outputPath or null;
    }
    // {
      reference = "(See: ${args.heading})";
    };

  # mkAgent :: { harness, name, description, content, model?, permission?, harnesses?, ... }
  #   AI agent definitions.
  #   Source: nixantic.sources.<source-owner>.agents.*, keyed by artifact key.
  #
  #   Required
  #     content      - Agent instruction body, placed after frontmatter.
  #     description  - Frontmatter description.
  #
  #   Optional (authored)
  #     name         - Display name. Defaults to filename stem.
  #     model        - Attrset keyed by harness name. Each value can be:
  #                    - String: model name only (e.g. { claude = "sonnet"; opencode = "gpt-4"; })
  #                    - Attrset: { model = "..."; effort = "..."; } (e.g. { claude = { model = "sonnet"; effort = "high"; }; })
  #                    Constructor selects model.<active-harness> and extracts model and optional effort.
  #                    Harness-rendered: Claude renders as `model` and `effort`; OpenCode renders as `model` and `reasoningEffort`.
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
      selectedHarnessValue = if model != null then model.${args.harness.name} or null else null;

      # Parse model value: can be string (model-only) or attrset (model + effort)
      selectedModel =
        if selectedHarnessValue != null then
          if builtins.isString selectedHarnessValue then
            selectedHarnessValue
          else if builtins.isAttrs selectedHarnessValue then
            selectedHarnessValue.model or null
          else
            null
        else
          null;

      selectedEffort =
        if selectedHarnessValue != null && builtins.isAttrs selectedHarnessValue then
          selectedHarnessValue.effort or null
        else
          null;

      permission = args.permission or null;
      selectedPermission = if permission != null then permission.${args.harness.name} or null else null;
    in
    renderArtifact {
      inherit (args)
        harness
        key
        name
        description
        content
        ;
      kind = "agent";
      authoredOutputPath = args.outputPath or null;
      model = selectedModel;
      effort = selectedEffort;
      permission = selectedPermission;
    }
    // {
      reference = mkAgentReference args.name;
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
  #     model        - Attrset keyed by harness name. Each value can be:
  #                    - String: model name only
  #                    - Attrset: { model = "..."; effort = "..."; }
  #                    Constructor selects model.<active-harness> and extracts model and optional effort.
  #                    Harness-rendered: Claude renders as `model` and `effort`; OpenCode renders as `model` and `reasoningEffort`.
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
      selectedHarnessValue = if model != null then model.${args.harness.name} or null else null;

      # Parse model value: can be string (model-only) or attrset (model + effort)
      selectedModel =
        if selectedHarnessValue != null then
          if builtins.isString selectedHarnessValue then
            selectedHarnessValue
          else if builtins.isAttrs selectedHarnessValue then
            selectedHarnessValue.model or null
          else
            null
        else
          null;

      selectedEffort =
        if selectedHarnessValue != null && builtins.isAttrs selectedHarnessValue then
          selectedHarnessValue.effort or null
        else
          null;

      optional = name: args.${name} or null;
    in
    renderArtifact {
      inherit (args)
        harness
        key
        name
        description
        content
        ;
      kind = if kind == "directory" then "skill" else "command";
      authoredOutputPath = args.outputPath or null;
      model = selectedModel;
      argumentHint = optional "argumentHint";
      metadata = optional "metadata";
      effort = selectedEffort;
      context = optional "context";
      agent = optional "agent";
      allowedTools = optional "allowedTools";
      whenToUse = optional "whenToUse";
      disableModelInvocation = optional "disableModelInvocation";
      userInvocable = optional "userInvocable";
      subtask = optional "subtask";
    }
    // {
      reference = mkReference (if kind == "directory" then "skill" else "command") args.name;
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
  mkSkillFile =
    args:
    renderArtifact {
      inherit (args)
        harness
        key
        content
        skillKey
        subPath
        ;
      kind = "skillFile";
      authoredOutputPath = args.outputPath or null;
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
  #     model        - Attrset keyed by harness name. Each value can be:
  #                    - String: model name only
  #                    - Attrset: { model = "..."; effort = "..."; }
  #                    Constructor selects model.<active-harness> and extracts model and optional effort.
  #                    Harness-rendered: Claude renders as `model` and `effort`; OpenCode renders as `model` and `reasoningEffort`.
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
        key = args.key or name;
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
      mkReference
      mkAgentReference
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
    renderArtifact
    ;
}
