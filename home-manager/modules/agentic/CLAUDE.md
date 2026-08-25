# Agentic Personal Layer

This tree owns all production instruction sources, acceptance checks, and AP runtime glue.

## Boundary

- Production instructions live under `instructions/`.
- Production acceptance checks live under `checks/`.
- Runtime glue lives under `claude/`, `opencode/`, `pi/`, and the module files in this tree.
- Generic renderer, module, check, and helper changes belong in the local `nixantic/` flake.

## Where To Look

- For production instruction or acceptance changes, edit the source `.nix` files in this tree.
- For generic framework changes, read and edit `nixantic/CLAUDE.md` and the source under `nixantic/`.
- For Home Manager wiring, read `default.nix` and `nixantic.nix`.

## Notes

Generated outputs under `result/` and downstream configuration trees are never edited. Change the
source `.nix` files and regenerate them with the validation commands.

## Validation

- Do not add production checks that assert AP's production instruction wording or policy content. Keep deterministic code/configuration checks and normal Nixantic framework validation.
- Build production instruction packages and inspect their generated output directly:
  - `./x agent build`: build the rendered production instruction package to `./result`.
  - `NIXANTIC_VCS_MODE=git ./x agent build`: build the Git-mode package.
- `HOST=deskapp ./x home check`: evaluate the current Home Manager configuration.
