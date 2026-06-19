# Agentic Personal Layer

Personal runtime glue built on top of nixantic from `inputs.harness`.
The harness repo owns the reusable instruction renderer, Home Manager module, and built-in instruction corpus.
A local `harness/` checkout may or may not be present. If a task requires local `harness/` content and the directory is absent, report that rather than assuming it exists.

## Boundary

- The reusable nixantic framework and built-in instruction corpus live in the harness repo, consumed via `inputs.harness`.
- AP-specific runtime glue lives in this repo under `home-manager/modules/agentic/{claude,opencode,default.nix}`.

## Where To Look

- If you are changing the reusable framework or built-in instruction corpus, work in the harness repo and read `harness/CLAUDE.md` when that checkout exists.
- If you are changing how AP-specific runtime glue is wired into Home Manager, read `home-manager/modules/agentic/default.nix`.

## Notes

- This tree is personal to this repo. It consumes harness, but it is not the source of truth for the reusable framework or instruction corpus.
- The personal Home Manager module uses `nixantic.instructions.profile = "builtin"` (the default). If you need to change instructions, edit the harness repo's source `.nix` files rather than generated markdown outputs.

## Validation

- `./x agent build`: build the personal rendered instruction package to `./result` for inspection.
- `./x home check`: evaluate the current host's Home Manager configuration.
