# Nixantic

`nixantic/` is the reusable product surface for rendering AI-agent instruction files from Nix source
fragments and installing them through Home Manager or exposing them through flake outputs.

## Purpose

Use this doc for top-level orientation. Keep code as source of truth. This file should only hold
product-level contracts, subsystem boundaries, and lookup pointers.

## Primary Path

Normal consumers should:
- import `home-manager.nix`
- set `nixantic.sourceRoots`
- optionally set `nixantic.instructions.install.files`

Flake-side rendering through `default.nix` and direct `lib.mkInstructions` use are advanced paths for
checks, tests, generated sources, or local inspection.

## Product Boundaries

- `nixantic/` is the reusable layer. Personal corpus/workflow content belongs outside it.
- The Home Manager module is the primary integration surface.
- Flake outputs and direct rendering exist, but they are secondary to Home Manager consumption.
- Source discovery, rendering, and installation are separate concerns; do not collapse them into one
  subsystem mentally.

## Hard Invariants

- `sourceRoots` are fragment-only authoring trees.
- Discovered and explicit sources merge additively; duplicate artifact keys fail.
- Runtime scope is flat; source-tree layout never creates runtime namespaces.
- Built-in harnesses are a closed product surface unless widened intentionally.
- Generated markdown is output, not authored source.

## Subsystems

- `instructions/`: renderer entrypoint, scope rules, harness behavior, checks, and renderer tests
- `source-sets.nix`: source-root discovery and duplicate diagnostics
- `home-manager.nix`: primary reusable installation/integration path
- `default.nix`: flake module and public `nixantic.lib` surface

## Renderer Invariants

- Every non-reserved `.nix` file under a source root must export `nixantic.sources.<owner>...`.
- Harness filtering is opt-in through authored `harnesses` fields.
- Default command block-reference injection is source-declared, not hardcoded engine policy.

## Renderer Map

- `instructions/default.nix`: renderer entrypoint and public instructions surface
- `instructions/scope.nix`: scope assembly, filtering, boilerplate injection, dual-output handling
- `instructions/builders.nix`: authoring field contracts and constructor behavior
- `instructions/harnesses/`: harness-specific rendering
- `instructions/frontmatter.nix`: shared frontmatter rendering helpers
- `instructions/checks.nix`: reusable renderer checks
- `instructions/tests/`: pure-eval coverage and fixtures

## Where To Look

- Change Home Manager options or install behavior: `home-manager.nix`
- Change flake outputs or public library wiring: `default.nix`
- Change source discovery or duplicate handling: `source-sets.nix`
- Change source shape or authored fields: `instructions/builders.nix`
- Change renderer filtering, boilerplate, or dual outputs: `instructions/scope.nix`
- Change rendered metadata or formatting: `instructions/harnesses/`, `instructions/frontmatter.nix`
- Change renderer validation expectations: `instructions/checks.nix`, `instructions/tests/`

## Guardrails

- If a fact is obvious from grep or file names, point to code instead of restating it here.
- Do not let historical naming drive current architecture decisions.
- Keep ordinary helper/generated Nix outside `sourceRoots`, or under reserved ignored paths.
