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
- `./x agent build` - Build nixantic instruction package to `./result`
- `./x fmt` - Format nix files (nixfmt)
- `./x check` - Eval all nixos/home/darwin configs for all hosts. Heavy, only use if you think a change could affect another host.

For quick iteration, use `check` first (fast eval) before `build`.
To find a missing hash, use build functions instead of trying to eval.

## Agentic Instructions

`nixantic/` contains the reusable instruction renderer and Home Manager module.
Repo's personal instructions in `home-manager/modules/agentic/instructions/`.
Before editing any opencode/claude/agentic source/instructions, read `nixantic/instructions/CLAUDE.md` and `home-manager/modules/agentic/CLAUDE.md`.

## Documentation

IMPORTANT: `docs/features/` is a symlink to a separate repo, checked-out at `./secrets`

This means:
- Project docs (`proj/` → `docs/features/.../00-*.md`) are NOT in this repo
- Changes to project docs are tracked in the secrets repo, not here
- `jj status` in dotfiles will NOT show project doc changes
- Only commit dotfiles changes (commands, skills, etc.) in this repo, don't need to commit secrets, I'll do it.

## Nix Conventions

- Format with `./x fmt` (nixfmt) before committing
- Eval first (`./x <home|nixos|...> check`), then build — builds are expensive
- Missing hash: build instead of eval (builds surface hash mismatch errors)
- Agent guidance: most nix changes are fine for senior dev. Use staff dev for complex nix structures (recursive attrsets, `lib.fix`, the `builders.nix` pattern)
