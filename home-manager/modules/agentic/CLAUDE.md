# Agentic Personal Layer

Personal instruction corpus and integration layer built on top of `nixantic`.
Read `nixantic/CLAUDE.md` to understand the reusable instruction system.

## Boundary

- Reusable renderer/module/source-discovery code lives in `nixantic/`.
- Personal authored instructions live in `home-manager/modules/agentic/instructions/`.
- Personal harness integrations live in `home-manager/modules/agentic/claude/` and `home-manager/modules/agentic/opencode/`.

## Where To Look

- If you are changing reusable `nixantic` behavior or the generic source contract, read `nixantic/instructions/CLAUDE.md`.
- If you are changing AP-specific instructions, start in `home-manager/modules/agentic/instructions/`.
- If you are changing how the personal corpus is wired into Home Manager, read `home-manager/modules/agentic/default.nix`.

## Notes

- This tree is personal to this repo. It uses `nixantic`, but it is not the
  reusable product itself.
- The personal Home Manager module points `nixantic.sourceRoots` at
  `./instructions`; edit source-set `.nix` files there, not installed/generated
  markdown outputs.

## Validation

- `./x agent build`: build the personal rendered instruction package to `./result` for inspection.
- `./x home check`: evaluate the current host's Home Manager configuration.
