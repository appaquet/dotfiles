# Agentic Instructions

Reference for authoring and maintaining the agentic instruction system that generates
CLAUDE.md (Claude) and AGENTS.md (opencode).

## Pipeline

Nix sources in each subdirectory are imported, filtered by harness, injected with
defaults, and assembled into a per-harness instruction map by `scope.nix`. Harness
renderers then turn that map into markdown. The entry point is `default.nix`.

## Directories

```
blocks/         → mkBlock           (no harness filtering; available to all)
agents/         → mkAgent           (filtered by harnesses)
commands/       → mkCommand         (filtered; pre-flight injected)
skills/<name>/  → mkSkill + files   (filtered; supports dual-output)
instructions/   → mkInstructions    (authored instruction files, recursive)
harnesses/      → harnesses         (renderer definitions: claude.nix, opencode.nix)
fixtures/       → test fixtures     (not shipped)
```

## Constructors

| Constructor        | Produces                                 | Source        |
|--------------------|------------------------------------------|---------------|
| `mkBlock`          | Reusable content blocks (embed + ref)    | `blocks/*.nix` |
| `mkSkill`          | Skill SKILL.md + sub-files               | `skills/*/default.nix` |
| `mkCommand`        | Slash command markdown                   | `commands/*.nix` |
| `mkAgent`          | Agent definition markdown                | `agents/*.nix` |
| `mkInstructions`   | Top-level instruction file (CLAUDE.md, AGENTS.md, rules) | `instructions/**/*.nix` |

Full data contracts (required/optional fields, outputs) are in `builders.nix` doc comments.
Construction pipeline (filtering, defaults, scope injection) is in `scope.nix`.

## Key Concepts

- **Blocks embedding** — blocks produce both `embed` (inline body) and `reference`
  (a pointer link). Other artifacts reference blocks to include shared content.
- **Harness filtering** — artifacts can declare `harnesses` to restrict which
  harnesses receive them. Omitted = all harnesses.
- **`forHarness`** — selects a harness-specific value from a `{ claude = ...; opencode = ...; }` attrset.
- **Dual-output** — commands can set `asSkill` to also generate a skill SKILL.md;
  skills can set `asCommand` to also generate a command markdown. Both accept
  booleans or per-harness attrsets.
- **Pre-flight injection** — all commands automatically receive a reference to
  the `pre-flight` block appended to their content (unless `noInjectPreFlight = true`).
- **Scope injection** — each `.nix` source receives `{ scope }` as its argument.
  The scope is a `lib.fix` self-referencing record with all processed artifacts
  available (e.g. `scope.blocks."some-block".reference`).

## Building & Testing

- `./x agent build` — build the instruction package, output to `./result`
- `./x check` — eval all configs (nixos/home/darwin), heavy — use on final pass
- `./x fmt` — format Nix files (nixfmt)
- `./x home build` — build home-manager config, install to system

For quick iteration: `agent build` to inspect output, `home check` before `home build`.

## Editing Workflow

1. Modify `.nix` sources (not installed markdown).
2. `./x agent build` — inspect rendered output in `./result`.
3. `./x home build` — install to system (then switch).
4. Use `/mem-edit` for instruction file changes (commands, skills, agents, supporting docs).
