# Nixantic contributor guide

Use this file when you work on this repository.

This repo is the standalone Nixantic renderer and integration framework. Consumers own their instruction sources.

The repo validates generic rendering and integration behavior, then produces generated configuration trees from consumer-authored Nix fragments.

## Work on the source, not generated output

- Edit source under `framework/`, `modules/`, `checks/`, `tools/`, and root docs.
- Do not hand-edit generated output. Rendered files belong to build results such as `result/claude/...` and `result/opencode/...`.
- Keep README human-focused. Use this file for contributor and agent guidance.

## Know the repo layout before editing

- `flake.nix`: public flake surface, exported packages, modules, and checks
- `modules/core.nix`: main module API, renderer wiring, wrapper packages, generic instruction checks
- `modules/home-manager.nix`: Home Manager install adapter
- `modules/flake-parts.nix`: flake-parts exposure layer
- `framework/`: renderer implementation, output adapters, post-processing, tests
- `checks/default.nix`: repo validation checks, including README example coverage
- `source-sets.nix`: source-root discovery and duplicate detection

## Follow these repo rules

- Keep framework fixtures neutral and unpublished. Consumers supply their instruction sources; do not add a built-in corpus.
- Keep the stable consumer surface at the module API exposed from the flake.
- When you change README examples or exported behavior, verify them against `flake.nix`, `modules/`, and `checks/default.nix`.
- Prefer changes in source fragments and renderer code over edits to rendered artifacts.
- Before creating or editing instructions, agents, commands, skills, rules, `CLAUDE.md`, or `AGENTS.md`, load and follow the `mem-writing` skill.
- Tests cover rendering, schemas, integrations, and executable behavior using neutral fixtures.
- Keep this file short. Do not restate code or README content unless it changes agent behavior.

## Watch the source-tree contract

- `_support/` and `tests/` under source roots are reserved and skipped by fragment discovery.
- Discovered source fragments must export `nixantic.sources`.
- Output-adapter file layout and naming live under `framework/harnesses/`.

## Verify before you finish

- `nix flake check --show-trace` validates the generic framework.
