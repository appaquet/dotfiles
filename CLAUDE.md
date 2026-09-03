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
- `./x check` - Eval all nixos/home/darwin configs for all hosts. Heavy, only use if you think a change could affect other hosts.

For quick iteration, use `check` first (fast eval) before `build`.
Always pipe `* build` output to temp file since it can be massive, then read it in part.
To find a missing hash, use build functions instead of trying to eval.

## Agentic Instructions

AP's personal agentic instructions (CLAUDE/AGENTS files, commands, skills, rules) are rendered by
`nixantic` from .nix sources under `home-manager/modules/agentic/instructions/`. `nixantic` is a
separate external repo (`github:appaquet/nixantic`) consumed as a flake input. For where to edit
what, the nixantic change workflow (clone, `path:` override, no-push), and validation: read
`home-manager/modules/agentic/CLAUDE.md` before editing.

`./nixantic` clones can exist in multiple dotfiles checkouts; identify the canonical one before
touching it (`home-manager/modules/agentic/CLAUDE.md`, Nixantic section).

## Documentation

IMPORTANT: project files should be stored into `~dotfiles/secrets/docs/features`

This means:

- Project docs (`proj/` → `~dotfiles/secrets/docs/features/.../00-*.md`) are NOT in this repo
- Changes to project docs are tracked in the secrets repo, not here
- `jj status` in dotfiles will NOT show project doc changes
- Only commit dotfiles changes (commands, skills, etc.) in this repo, don't need to commit secrets, I'll do it.

## Nix Conventions

- Format with `./x fmt` (nixfmt) before committing
- Eval first (`./x <home|nixos|...> check`), then build — builds are expensive
- Missing hash: build instead of eval (builds surface hash mismatch errors)
- Agent guidance: most nix changes are fine for mid dev. Use senior dev for complex nix structures,
  and staff if blocked
- When updating an overlay / fetchFromGithub dependency, set the rev to target (commit, tag, etc.),
  then set hash to `lib.fakeHash`, then build home/nixos. This will fail with the expected hash that
  you can then use. DON'T manually fetch dependencies to compute its hash.
