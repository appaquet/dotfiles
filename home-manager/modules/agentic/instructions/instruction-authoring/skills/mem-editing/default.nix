let
  main = {
    description = "Instructions to be used as soon as any instruction, CLAUDE.md, command, skill or agent file needs to be changed.";

    argumentHint = "[files or description]";

    content = ''
      # Instruction Editing Guidelines

      Guidelines for editing agent instruction sources for Claude and opencode.
      Load supporting files as needed for the specific component type being edited.

      ## File Locations

      Production instruction authoring lives in feature/domain instruction directories under `~/dotfiles/home-manager/modules/agentic/instructions/`.
      Use the existing source set that owns the workflow or create a new clearly named directory when adding a new feature/domain boundary.

      - `instructions/root-instructions/instructions/main.nix` — root instruction fragment (generates CLAUDE.md or AGENTS.md)
      - `instructions/development-workflow/instructions/rules/development.nix` — rule instruction fragment
      - `instructions/context-management/commands/ctx-load.nix` — slash command fragment
      - `instructions/instruction-authoring/skills/mem-editing/default.nix` — skill fragment with explicit bundled files
      - `instructions/agent-delegation/agents/staff-dev.nix` — agent fragment
      - `instructions/development-workflow/blocks/testing-principles.nix` — reusable content block fragment

      Renderer internals live in `nixantic/instructions/`:

      - `harnesses/` — harness-specific renderers and behavior
      - `frontmatter.nix` — structured frontmatter rendering helpers
      - `builders.nix` — central scope construction and constructors
      - `nixantic/source-sets/lib.nix` — free-form fragment discovery

      Generated markdown is produced via `./x agent build` and deployed by Home Manager.
      Always edit the Nix template sources above, not the generated output.

      ## When to Use

      Any time instruction files are created or modified: optimization, bug fixes, adding rules,
      refactoring, new commands/skills/agents.

      ## Editing Principles

      - Preserve all salient information - never silently drop content
      - Check for redundancy and conflicts across files before editing
      - Apply principles from supporting docs below (match the component type)
      - Consider surrounding style: load neighboring commands/skills/agents to match patterns
      - Use the active harness's question/prompt tool for ambiguities

      ## What to Check

      - Ambiguity - what could a fresh agent misinterpret?
      - Cross-file conflicts - do related files have contradicting rules?
      - Redundancy - is this duplicated elsewhere?
      - Missing context - does this assume knowledge not provided?

      ## Supporting Files

      - @references/core.md: Core principles (self-verification, minimal info, writing style)
      - @references/skills.md: Skill structure, naming, progressive disclosure, description guidelines
      - @references/commands.md: Slash command structure and optimization workflow
      - @references/instructions.md: Root instruction files, rule sources, reusable blocks, and structured prompting
      - @references/agents.md: Agent structure and patterns
      - nixantic/instructions/CLAUDE.md: full instruction authoring reference and data contracts
    '';
  };
in
{
  nixantic.sources.instruction-authoring.skills."mem-editing" = {
    kind = "directory";
    inherit main;
    files = {
      "references/agents.md" = {
        kind = "md";
        content = builtins.readFile ./references/agents.md;
      };
      "references/commands.md" = {
        kind = "md";
        content = builtins.readFile ./references/commands.md;
      };
      "references/core.md" = {
        kind = "md";
        content = builtins.readFile ./references/core.md;
      };
      "references/instructions.md" = {
        kind = "md";
        content = builtins.readFile ./references/instructions.md;
      };
      "references/skills.md" = {
        kind = "md";
        content = builtins.readFile ./references/skills.md;
      };
    };
  };
}
