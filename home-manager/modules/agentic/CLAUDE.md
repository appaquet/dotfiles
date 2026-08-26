# Agentic Personal Layer

This tree owns all production instruction sources, acceptance checks, and AP runtime glue.

## Boundary

- Production instructions live under `instructions/`: .nix fragments rendered by nixantic into harness artifacts (CLAUDE/AGENTS files, commands, skills, rules).
- Production acceptance checks live under `checks/`.
- Runtime glue lives under `claude/`, `opencode/`, `pi/`, and the module files in this tree.
- Generic renderer, module, and check changes belong in the external `nixantic` repo (see Nixantic).

## Where To Look

- For production instruction or acceptance changes, edit the source .nix files under `instructions/` and `checks/` — never the rendered artifacts (e.g. `~/.claude/commands/`, `~/.config/opencode/prompts/`, rendered CLAUDE/AGENTS files).
- For generic framework changes, work in a clone of the `nixantic` repo (see Nixantic) and read its `CLAUDE.md` first.
- For Home Manager wiring, read `default.nix` and `nixantic.nix`.

## Nixantic

`nixantic` (`github:appaquet/nixantic`) is a separate external repo, consumed as a flake input. The dotfiles `flake.nix` has a commented local `path:` override.

To change nixantic:
1. Clone the repo (e.g. into the gitignored `./nixantic` dir) + jj git colocate and make the changes there, as separate commits in that repo, alongside the dotfiles change. Don't use https remote, but git+ssh.
   It may already exists, in that case, update to latest.
2. Switch the dotfiles nixantic input to the `path:` override so dotfiles acts on the unpushed local changes.
3. Never push to the nixantic repo: when a push is required, tell the user and let the user push. After the push, the user removes the `path:` override and updates the input back to `github:appaquet/nixantic` (`nix flake update nixantic`).

Validate the standalone framework with `nix flake check --show-trace` inside a nixantic clone.

## Editing Production Instructions

Before editing anything under `instructions/`, load and follow the `mem-writing` skill.

Nixantic sources compose prompt text at build time. They do not define runtime workflow or control flow.

- Framework fields affect rendering; extra block attributes are text fragments until interpolated.
- Main instructions become persistent context.
- Commands become complete prompts when invoked.
- Source position controls text placement, not execution timing.
- The model sees rendered text, not Nix attributes, block provenance, or AP's external workflow.

Before planning an instruction change:

1. Review the full branch diff.
2. Render the affected artifacts.
3. Inspect the complete model-visible context.
4. Describe the behavioral change without Nix terminology.
5. Remove every file change that has no model-visible effect.

## Notes

Generated outputs under `result/` and downstream configuration trees are never edited. Change the
source `.nix` files and regenerate them with the validation commands.

## Validation

- Use `checks/corpus.nix` only for quick smoke and deterministic structural/configuration checks. Contributors must never add assertions for exact instruction text, policy wording, or production content; inspect generated output directly instead.
- Build production instruction packages and inspect their generated output directly:
  - `./x agent build`: build the rendered production instruction package to `./result`.
  - `NIXANTIC_VCS_MODE=git ./x agent build`: build the Git-mode package.
- `HOST=deskapp ./x home check`: evaluate the current Home Manager configuration.
