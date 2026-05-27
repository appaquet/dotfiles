{ pkgs, lib }:

let
  frontmatter = import ./frontmatter.nix;
  files = import ./files.nix { inherit pkgs lib; };

  # Constructor reference — documents the full authoring contract for each artifact
  # type. Scope-injected fields are listed for awareness (authors should not set
  # them). Fields consumed by scope.nix before the constructor runs are marked as
  # scope-consumed.

  # mkBlock :: { heading?, content, tag?, taggedContent?, ... }
  #   Reusable content blocks available in every harness scope.
  #   Source: blocks/*.nix, imported with { scope }, keyed by filename stem.
  #
  #   Required
  #     content        - Block body text.
  #
  #   Optional
  #     heading        - Section title. Embed emits `## heading`; reference emits
  #                      `(See: heading)`.
  #     tag            - XML tag name. Wraps taggedContent; reference emits `<tag>`.
  #     taggedContent  - XML tag body. Required when `tag` is set; replaces
  #                      `content` inside the XML wrapper.
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
      body = if tag != null then "${content}\n<${tag}>\n${inner}</${tag}>" else content;
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

  # mkInstructions :: { heading, content, outputPath?, harnesses?, ... }
  #   Authored instruction files (CLAUDE.md, AGENTS.md, rule files).
  #   Source: instructions/**/*.nix, imported recursively with { scope },
  #     keyed by relative path without .nix extension.
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

  # mkAgent :: { harness, name, description, content, model?, harnesses?, ... }
  #   AI agent definitions.
  #   Source: agents/**/*.nix, imported with { scope }, keyed by filename stem.
  #
  #   Required
  #     content      - Agent instruction body, placed after frontmatter.
  #     description  - Frontmatter description.
  #
  #   Optional (authored)
  #     name         - Display name. Defaults to filename stem.
  #     model        - Attrset keyed by harness name (e.g. { claude = "sonnet"; }).
  #                    Constructor selects model.<active-harness> or null.
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
      frontmatter = args.harness.renderAgentFrontmatter {
        inherit (args) name description;
        model = selectedModel;
      };
    in
    {
      embed = "${frontmatter}\n${args.content}";
      reference = "(See agent: ${args.name})";
    };

  # mkSkill :: { harness, name, description, content, kind?, outputPath?, model?, harnesses?, asCommand?, argumentHint?, license?, compatibility?, metadata?, effort?, context?, agent?, allowedTools?, whenToUse?, disableModelInvocation?, userInvocable?, subtask?, ... }
  #   Skill and command definitions. Used for directory skills and internally for
  #   command↔skill dual output.
  #   Source: skills/<directory>/default.nix for directory skills; also used by
  #     scope for command-derived skills and skill-derived commands.
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
  #     Both harnesses:  name, description, license, compatibility, metadata
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
            license = optional "license";
            compatibility = optional "compatibility";
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
  #   Source: .nix sub-files under skills/<directory>/, imported with { scope }.
  #     .md sub-files bypass this constructor and are copied raw.
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

  # mkCommand :: { harness, name, description, content, kind?, outputPath?, model?, harnesses?, asSkill?, noInjectPreFlight?, argumentHint?, effort?, context?, agent?, allowedTools?, subtask?, ... }
  #   Slash-command definitions. Delegates to mkSkill with kind="flat".
  #   Source: commands/**/*.nix, imported with { scope }, keyed by filename stem.
  #
  #   Required
  #     content      - Command body text. Scope appends pre-flight reference before
  #                    constructor call (see noInjectPreFlight).
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
  #     noInjectPreFlight - Suppress pre-flight block injection into content.
  #
  #   Scope-injected (authors do not set)
  #     harness      - Active harness renderer.
  #     kind         - "flat".
  #     outputPath   - Rendered file path (commands/<name>.md).
  #
  #   Returns: { embed, reference, outputPath }
  mkCommand =
    args:
    mkSkill (
      {
        kind = "flat";
        outputPath = "commands/${args.name or (throw "mkCommand requires name")}.md";
      }
      // args
    );

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

  renderFrontmatter = frontmatter.renderFrontmatter;
  importDir = files.importDir;
  importFlatTree = files.importFlatTree;
  importBlocksTree = files.importBlocksTree;
  importSkillsDir = files.importSkillsDir;

  scopeMod = import ./scope.nix {
    inherit
      mkBlock
      mkInstructions
      mkAgent
      mkSkill
      mkSkillFile
      mkCommand
      forHarness
      renderFrontmatter
      importDir
      importFlatTree
      importBlocksTree
      importSkillsDir
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
    injectCommandPreFlight
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
    renderFrontmatter
    importDir
    importFlatTree
    importBlocksTree
    importSkillsDir
    ;
}
