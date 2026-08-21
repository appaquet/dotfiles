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

The local `nixantic/` flake owns the generic instruction renderer, Nix modules, framework checks,
and helper packages. The `home-manager/modules/agentic/` tree owns production instruction sources,
acceptance checks, and AP runtime glue. Read the relevant tree's `CLAUDE.md` before editing it.

Run `nix flake check path:./nixantic --show-trace` for the standalone framework. Run
`HOST=deskapp ./x home check` and `./x agent build` for the current dotfiles integration; use
`NIXANTIC_VCS_MODE=git ./x agent build` to check the Git rendering mode. The parent currently uses
`path:./nixantic`; future extraction should replace that input URL with the published repository
URL and update the lock file. Choose a license before publishing or extracting nixantic; none is
selected in this repository.

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
