# dotfiles

## Building & Testing

Use `./x` script for building and evaluating nix configurations:

- `./x nixos check` - Eval nixos config for current host
- `./x nixos build` - Build nixos config
- `./x home check` - Eval home-manager config
- `./x home build` - Build home-manager config
- `./x darwin check` - Eval darwin config
- `./x darwin build` - Build darwin config
- `HOST=deskapp ./x nixos check` - Check specific host
- `./x check` - Eval all nixos/home/darwin configs for all hosts
- `./x agent build` - Build agentic instruction package → `./result`
- `./x fmt` - Format nix files (nixfmt)

For quick iteration, use `check` first (fast eval) before `build`.
To find a missing hash, use build functions instead of trying to eval.

## Agentic Instructions

Agent instructions (Claude + Opencode) share a single `nix` source tree in
`home-manager/modules/agentic/instructions/`:

- `blocks/` - reusable content blocks
- `agents/` - agent definitions
- `commands/` - slash command definitions
- `skills/` - skill definitions
- `instructions/rules/` - rule files

Rendered via harness-specific frontmatter into `CLAUDE.md` (Claude) and `AGENTS.md` (opencode). `./x agent build` renders to `./result` for inspection.

Editing: modify `.nix` sources, not installed markdown. Use `/mem-edit` for instruction file changes (commands, skills, agents, supporting docs). `./x home build` and then switch to install in system.

## Documentation

`docs/features/` is a symlink to a **separate ./secrets repo**. This means:

- Project docs (`proj/` → `docs/features/.../00-*.md`) are NOT in this repo
- Changes to project docs are tracked in the secrets repo, not here
- `jj status` in dotfiles will NOT show project doc changes
- Only commit dotfiles changes (commands, skills, etc.) in this repo

## Nix Conventions

- Format with `./x fmt` (nixfmt) before committing
- Eval first (`./x <home|nixos|...> check`), then build — builds are expensive
- Missing hash: build instead of eval (builds surface hash mismatch errors)
- Agent guidance: most nix changes are fine for senior dev. Use staff dev for complex nix structures (recursive attrsets, `lib.fix`, the `builders.nix` pattern)
