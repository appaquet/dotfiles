# Nixantic Instructions

Compact reference for nixantic, the Nix instruction system that renders
CLAUDE.md (Claude) and AGENTS.md (opencode).

## Pipeline

Generic renderer code lives in `nixantic/`. Corpus sources may live in any tree.
Any non-helper `.nix` file under a source tree may contribute explicit
`nixantic.sources.<name>` fragments. `scope.nix` normalizes all branches,
flattens artifacts by exported kind, applies harness filtering/default
injection, and exposes flat runtime scopes. Harness renderers turn that scope
into markdown; `default.nix` is the renderer entrypoint.

The primary reusable API is the Home Manager module exposed as
`homeManagerModules.default` from `nixantic/home-manager.nix`: import it, set
`nixantic.sourceRoots = [ ./instructions ]`, optionally set
`nixantic.instructions.install.files`, and let Home Manager install the rendered
files. Flake-side rendered outputs remain an advanced/local inspection surface,
not the normal integration path.

## Directories

```
<source-tree>/**/<fragment>.nix                 → explicit source-set fragments
<source-tree>/**/default.nix                    → normal fragment file
<source-tree>/**/_support/                      → helper code, not discovered
harnesses/                                      → claude/opencode renderers
tests/                                          → pure-eval tests
tests/fixtures/                                 → fixture source trees
```

`nixantic` does not require a specific source-tree taxonomy. A consumer may keep
all authored fragments in one tree or split them by feature, domain, or harness
concern, as long as each discovered file exports explicit
`nixantic.sources.<owner>` data. Use `sourceRoots` for normal path-based
discovery; use low-level `sources` for generated data, tests, and advanced
callers that already have source declarations.

## Source Contract

- Fragment files export module-shaped attrsets under
  `nixantic.sources.<owner>.<kind>.<key>`. The filesystem path never
  declares artifact kind.
- Source-set values are lazy attrsets of raw artifact values. Values may be plain
  attrsets or functions of `{ scope }`.
- Source-set names are authoring/provenance labels only. Runtime references stay
  flat: `scope.blocks.*`, `scope.commands.*`, `scope.agents.*`, `scope.skills.*`,
  and `scope.instructions.*`.
- Artifact keys are explicit attr names within each kind. Duplicate flat keys are
  errors. `sourceRoots` and `sources` are additive; duplicates fail instead of
  applying override precedence. Discovered diagnostics include owner and file
  path, while explicit low-level sources are labelled separately.
- Use `scope.blocks.*`, `scope.forHarness`, and stable scope metadata from
  source-set functions. Do not reference the source's own processed artifact or
  final `scope.instructions` from the same source; those are circular.
- Commands receive the pre-flight block unless `noInjectPreFlight = true`.
- Directory skills may include bundled `.md` and `.nix` subfiles. Nix subfiles are
  evaluated with `{ scope }`; markdown subfiles are copied as content.

## Constructors

| Constructor      | Source branch suffix             | Produces |
|------------------|----------------------------------|----------|
| `mkBlock`        | `.blocks.*`                      | Reusable `embed`/`reference` content |
| `mkCommand`      | `.commands.*`                    | Slash command markdown |
| `mkAgent`        | `.agents.*`                      | Agent definition markdown |
| `mkSkill`        | `.skills.<name>`                 | `SKILL.md` plus bundled files |
| `mkInstructions` | `.instructions.*`                | Root/rule instruction files |

Full field contracts are documented in `builders.nix`. Free-form fragment
discovery lives in `../source-sets/lib.nix`. Scope normalization, harness
filtering, dual-output handling, and pre-flight injection live in `scope.nix`.

## Key APIs and Safety Constraints

- `scope.forHarness { claude = ...; opencode = ...; default = ...; }` selects
  harness-specific values.
- `harnesses = [ "claude" "opencode" ]` restricts artifact rendering; omitted
  means all harnesses.
- `asSkill` on commands and `asCommand` on skills create dual outputs. Both
  accept booleans or per-harness attrsets.
- Flat runtime semantics are intentional: never introduce runtime paths scoped by
  source-set directory name.
- Edit Nix source-set files, not generated markdown in installed config paths.

## Advanced Rendering and Checks

- Consumers normally integrate through Home Manager, not by building rendered
  outputs directly.
- For advanced use, `nixantic.lib.mkInstructions` can render a package from
  `{ pkgs, lib, sourceRoots, sources, postProcess }`. `sourceRoots` is the
  ergonomic path input; `sources` remains the low-level escape hatch and merges
  additively with discovered roots.
- `nixantic` may also expose a rendered package/check surface from a flake when
  that flake wires one intentionally, but that is optional and not the primary
  integration path.
