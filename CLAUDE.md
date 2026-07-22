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
Always pipe `* build` output to temp file since it can be massive, then read it in part.
To find a missing hash, use build functions instead of trying to eval.

## Agentic Instructions

`inputs.harness` consumes the external `harness` repo, which owns nixantic — the reusable instruction renderer, Home Manager module, and built-in instruction corpus.

A local `harness/` checkout may or may not be present. It is only kept when needed for local work. If a task requires local `harness/` content and the directory is absent, report that rather than assuming it exists.

If you are editing the reusable agentic framework or built-in instruction corpus, work in the harness repo and read `harness/CLAUDE.md` when that checkout exists. If you are editing AP-specific runtime glue in this repo, read `home-manager/modules/agentic/CLAUDE.md`.

If you need to iterate on the harness with local changes, change the flake path in `flake.nix` to point to your local `harness/` checkout first. You may need to update with `nix flake update harness` for latest changes. Revert flake.nix when done, tell me to commit, push and update.

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
- When updating rev (commit,tag,etc.) of a nix fetch, set hash to `lib.fakeHash` so Nix computes the correct value at fetch time
