# AP Personal Layer

AP-only guidance for the personal corpus that consumes `nixantic`.

## Boundary

- Reusable product behavior lives in `nixantic/`.
- AP-authored instruction sources live in `home-manager/modules/agentic/instructions/`.
- Personal Claude/opencode integration lives in `home-manager/modules/agentic/claude/` and
  `home-manager/modules/agentic/opencode/`.

## Authoring Surface

- Work inside the owning feature/domain folder under
  `home-manager/modules/agentic/instructions/`.
- Read adjacent files in that owner before changing naming, wording, or structure.
- Edit the Nix or raw markdown source files in the tree, not installed files under `~/.claude`,
  `~/.config/opencode`, or rendered build output.

Representative paths:

- `root-instructions/instructions/main.nix`
- `development-workflow/instructions/rules/development.nix`
- `context-management/commands/ctx-load.nix`
- `instruction-authoring/skills/mem-editing/default.nix`
- `agent-delegation/agents/staff-dev.nix`

## Local Validation

- `./x agent build`: build the personal rendered package for inspection.
- Inspect `result/claude/` and `result/opencode/` when the change affects generated instruction text.
- `./x home check`: only when the change also affects personal Home Manager wiring or consumer
  integration behavior.

## Personal-Layer Bias

Keep repo-local conveniences here clearly labeled as AP-specific. Do not move them into reusable
`nixantic` docs unless they become true product behavior.
