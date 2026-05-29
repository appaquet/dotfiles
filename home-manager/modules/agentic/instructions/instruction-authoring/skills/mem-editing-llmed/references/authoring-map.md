# Instruction Authoring Map

Shared guidance for authored instruction sources across the reusable `nixantic` layer and AP's
personal corpus.

## Shared Rules

- Source files return Nix data, not hand-written YAML frontmatter.
- Harness-specific differences stay local through structured fields and `scope.forHarness`.
- Generated `CLAUDE.md`, `AGENTS.md`, command files, agent files, and `skills/*/SKILL.md` are outputs,
  not the authoring surface.
- Use portable references such as `@references/...`, `@rules/...`, and `@skills/...`.
- Reuse nearby patterns before inventing new structure.

## Component Map

| Component | Authored path | Source shape | Rendered output |
|---|---|---|---|
| Root instructions | `*/instructions/main.nix` | `mkInstructions` data | `CLAUDE.md` / `AGENTS.md` |
| Rules | `*/instructions/rules/*.nix` | `mkInstructions` data | `rules/*.md` |
| Blocks | `*/blocks/*.nix` | `mkBlock` data | embedded/reference-only content |
| Commands | `*/commands/*.nix` | `mkCommand` data | `commands/<name>.md` |
| Agents | `*/agents/*.nix` | `mkAgent` data | `agents/<name>.md` |
| Skills | `*/skills/<name>/default.nix` | `mkSkill` data | `skills/<name>/SKILL.md` |
| Skill subfiles | `*/skills/<name>/references/*.md` or sibling `*.nix` | raw markdown or generated skill file data | `skills/<name>/*` |

## Component-Specific Notes

### Instructions and rules

- Keep root instruction files thin and globally applicable.
- Move detailed workflow policy into blocks, rules, skills, or commands.

### Blocks

- Use blocks for shared text that multiple instruction sources compose.
- Keep block names stable; consumers should not care where the block lives physically.

### Commands

- Put workflow-specific gates and stop points in command content.
- Use `Task` wording for tracked work and keep approval rules explicit.

### Agents

- Make descriptions specific to the review or execution role.
- Keep shared mechanics in blocks when multiple agents use the same workflow.

### Skills

- Keep `default.nix` focused on routing and activation-time guidance.
- Move bulky detail into bundled references or stable repo anchors.
- Use references only one step deep when possible so the load path stays obvious.

## Stable Reusable Anchor

When the change touches reusable renderer behavior, contracts, or lookup paths, use
`/Users/appaquet/dotfiles/nixantic/CLAUDE.md` as the top-level anchor, then jump to the exact file it
points at.
