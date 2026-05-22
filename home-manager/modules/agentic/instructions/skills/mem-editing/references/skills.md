# Skill Source Structure

Guidelines for writing skills in the nixified multi-harness instruction authoring system. Skill
source files return plain Nix attrsets only; `makeScope` in `tooling.nix` applies `mkSkill`
centrally and harnesses render the generated markdown.

Source files never hand-write YAML frontmatter.

## File Structure

```
skill-name/                  # kebab-case, no spaces/capitals/underscores
├── default.nix              # Required source data for mkSkill
├── references/              # Optional raw markdown copied as skill subfiles
│   └── detailed-guide.md
└── extra.nix                # Optional processed skill subfile via mkSkillFile
```

Generated output is harness-owned:

* `instructions/skills/<name>/default.nix` returns data for `mkSkill`
* `instructions/skills/<name>/references/*.md` is copied raw as skill subfiles
* `instructions/skills/<name>/*.nix`, excluding `default.nix`, is processed with `mkSkillFile`
* `makeScope` derives the skill name from the directory name
* Harnesses generate `skills/<name>/SKILL.md`

### Naming Rules

* Folder: kebab-case only (`notion-project-setup`, not `Notion_Project_Setup`)
* Main source file: exactly `default.nix`
* Do not add `name` to the skill source; the name is derived from the folder by `makeScope`
* Do not edit generated `SKILL.md` files; update source data instead
* Put long supporting docs in `references/` and link them with `@references/filename.md`

## Structured Metadata Fields

Skill `default.nix` files use structured Nix fields. Constructors and harnesses decide how those
fields render to frontmatter, generated markdown, or runtime metadata.

Common fields:

| Field | Purpose | Harness notes |
|-------|---------|---------------|
| `description` | Skill discovery and trigger text | Supported by skill harnesses |
| `argumentHint` | Optional argument display text | Rendered only by harnesses that support it |
| `content` | Main skill body rendered into generated `SKILL.md` | Primary instruction text |
| `effort` | Model effort metadata | Harness-selected output |
| `model` | Model preference metadata | Harness-selected output |
| `context` | Context-loading metadata | Harness-selected output |
| `agent` | Agent metadata for harnesses that support it | Harness-selected output |
| `allowedTools` | Tool restrictions for Claude output | Claude-only field |
| `subtask` | Subtask metadata for OpenCode output | OpenCode-only field |
| `whenToUse` | Optional source-level applicability guidance | Use only if consumed by the target harness |

Use `scope.forHarness` when a value differs by harness:

```nix
{ scope }:

{
  description = "Edit instruction source files in the nixified authoring system.";
  model = scope.forHarness {
    claude = "sonnet";
    opencode = "gpt-5.5";
  };
  allowedTools = [ "Read" "Grep" "Glob" "Edit" ];
  subtask = false;

  content = ''
    # Instruction Editing Guidelines

    Use this skill when modifying instruction source files.
  '';
}
```

### Frontmatter-Sensitive Values

Frontmatter is rendered from structured fields by each harness. Treat metadata values as
frontmatter-sensitive even though source files do not contain YAML.

* Keep `description` concise and plain text
* Avoid XML angle brackets in metadata fields unless the target harness explicitly supports them
* Put markdown-heavy instructions in `content`, not metadata fields
* Use structured Nix fields rather than embedding generated frontmatter manually

## Description Field

The description determines when a skill is discovered or loaded. Structure it as:

`[What it does] + [When to use it / trigger phrases] + [Key capabilities]`

<good-example>
description = "Extract text and tables from PDF files, fill forms, and merge documents. Use when working with PDFs or mentioning document extraction, PDF conversion, or PDF forms.";
</good-example>

<bad-example>
description = "Helps with documents.";
</bad-example>

<bad-example>
description = "Creates sophisticated multi-page documentation systems.";
</bad-example>

### Negative Triggers

When a skill over-triggers on unrelated requests, add exclusions to `description`:

```nix
description = "Advanced data analysis for CSV files. Use for statistical modeling, regression, and clustering. Do NOT use for simple data exploration.";
```

### Triggering Diagnostics

Under-triggering, where a skill does not load when it should:

* Description too vague or generic
* Missing trigger phrases users actually say
* Missing file types or technical terms
* Fix: add specific phrases, file types, and domain keywords

Over-triggering, where a skill loads for unrelated requests:

* Description too broad
* Overlapping scope with another skill
* Fix: add negative triggers, narrow scope, and clarify boundaries

Debug by asking the agent when it would use the skill. The answer should reflect the description
and boundaries clearly.

## Progressive Disclosure

Skills use source-level progressive disclosure:

1. **Structured metadata in `default.nix`** - small routing fields used by harnesses for discovery
2. **`content` in `default.nix`** - main generated `SKILL.md` body loaded when the skill triggers
3. **`references/*.md`** - raw supporting docs loaded only when needed
4. **Non-default `*.nix` files** - processed generated subfiles for content needing Nix interpolation

### Size Guidance

* `content`: concise activation-time guidance, ideally 1,500-2,000 words or less
* Move detailed reference material to `references/`
* Keep generated subfiles focused on one topic so they can be loaded selectively

### What Goes Where

`default.nix` metadata:

* `description` and harness-specific routing fields
* Model/tool/context metadata
* Short applicability hints

`default.nix` `content`:

* Purpose statement and quick-start guidance
* Essential instructions and workflow steps
* Portable links to supporting files with `@references/filename.md`

`references/*.md`:

* Extended documentation and detailed patterns
* Additional examples and API specifications
* Edge cases and troubleshooting

Non-default `*.nix` files:

* Processed skill subfiles that need shared blocks, Nix interpolation, or harness-specific text

### Avoiding Duplication

* Keep detailed principles in supporting files
* Keep `content` focused on what must be available when the skill triggers
* Use portable references such as `@references/best-practices.md`, `@skills/name/SKILL.md`, and `@rules/filename.md`
* Use `scope.blocks.*` for shared instruction blocks instead of repeating shared text
* Keep each piece of information in one place: metadata, `content`, a reference file, or a shared block

## `default.nix` Template

```nix
{ scope }:

{
  description = "Specific capability with trigger phrases. Include file types, concrete capabilities, and natural phrases users would say.";
  argumentHint = "[optional-arg]";
  allowedTools = [ "Read" "Grep" "Glob" ];
  subtask = false;

  content = ''
    # Skill: skill-name

    Brief purpose statement.

    ## When to Use

    Specific triggers and scenarios.

    ## Core Principles

    Key guidelines. Reference supporting docs with `@references/filename.md`.

    ## Workflow

    Clear steps for different scenarios.

    ## Supporting Files

    * `@references/referenced-file.md`: Purpose
  '';
}
```

## Instruction Best Practices

* Be specific and actionable: "Run `scripts/validate.py --input {file}`" not "Validate the data"
* Include error handling for common failures
* Reference bundled resources with portable paths
* Front-load critical instructions at the top of `content`
* Use verification steps: "Run X to confirm Y"
* Generalize language across harnesses unless a rule is explicitly Claude-only or OpenCode-only
