{ scope }:
{
  description = "Instructions to be used as soon as any instruction, CLAUDE.md, command, skill or agent file needs to be changed.";

  argumentHint = "[files or description]";

  content = ''
    # Instruction Editing Guidelines

    Guidelines for editing agent instruction sources for Claude and opencode.
    Load supporting files as needed for the specific component type being edited.

    ## File Locations

    All my personal instruction Nix templates live in `~/dotfiles/home-manager/modules/agentic/instructions/`:

    - `instructions/instructions/main.nix` — root instruction data (generates CLAUDE.md or AGENTS.md)
    - `instructions/instructions/rules/` — rule instruction data
    - `instructions/commands/` — slash command definitions
    - `instructions/skills/` — skill definitions
    - `instructions/agents/` — agent definitions
    - `instructions/blocks/` — reusable content blocks
    - `instructions/harnesses/` — harness-specific renderers and behavior
    - `instructions/frontmatter.nix` — structured frontmatter rendering helpers
    - `instructions/builders.nix` — central scope construction and constructors

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
    - home-manager/modules/agentic/instructions/CLAUDE.md: full instruction authoring reference and data contracts
  '';
}
