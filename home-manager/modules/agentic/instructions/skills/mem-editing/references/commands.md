# Slash Command Source Structure

Guidelines for writing slash commands in the nixified multi-harness instruction authoring system.
Command source files return plain Nix attrsets only; `makeScope` in `builders.nix` applies
`mkCommand` centrally and harnesses render supported fields.

Source files never hand-write YAML frontmatter.

## Template

```nix
{ scope }:

{
  description = "Brief one-line purpose";
  argumentHint = "[optional-arg]";

  content = ''
    # Command Title

    Clear purpose statement.

    Target: `$ARGUMENTS`

    ## Instructions

    1. STOP, follow pre-flight instructions
       THEN, continue

    2. 🔳 Ensure context is loaded
       - Skip if already done

    3. 🔳 Do main work
       - Details...
  '';
}
```

Optional metadata can be added when needed:

```nix
{ scope }:

{
  description = "Plan implementation work from project docs.";
  argumentHint = "[task-or-phase]";
  model = scope.forHarness {
    claude = "sonnet";
    opencode = "gpt-5.5";
  };
  effort = "high";
  allowedTools = [ "Read" "Grep" "Glob" ];
  subtask = false;

  content = ''
    # Plan Implementation

    Use `$ARGUMENTS` to identify the target work.
  '';
}
```

## Structured Metadata Fields

Common command fields:

| Field | Purpose | Harness notes |
|-------|---------|---------------|
| `description` | Command summary and discovery text | Supported by command harnesses |
| `argumentHint` | Optional argument display text | Rendered only by harnesses that support it |
| `content` | Main command body | Rendered into `commands/<name>.md` |
| `effort` | Model effort metadata | Harness-selected output |
| `model` | Model preference metadata | Harness-selected output |
| `context` | Context-loading metadata | Harness-selected output |
| `agent` | Agent metadata for harnesses that support it | Harness-selected output |
| `allowedTools` | Tool restrictions for Claude output | Claude-only field |
| `subtask` | Subtask metadata for OpenCode output | OpenCode-only field |

Use `scope.forHarness { claude = ...; opencode = ...; }` for harness-specific metadata or
content fragments. Keep the source as structured Nix data.

## Command Guidelines

* Front-load critical rules, approval gates, and stop points that are specific to the workflow
* Treat `/proceed`, `/implement`, and other approval gates as workflow-specific, not default command boilerplate
* Use phases for multi-step workflows
* Use one emphasis level: CRITICAL or Important, not both
* Use imperative mood throughout command instructions
* Refer to the generic `Task` tool name for task tracking
* Use portable references: `@references/filename.md`, `@skills/name/SKILL.md`, and `@rules/filename.md`
* Use `scope.blocks.*` for shared instruction blocks instead of duplicating common text
* Generalize language across harnesses unless a rule is explicitly Claude-only or OpenCode-only

## Task Tracking

Steps marked with 🔳 become `Task` tool items under the active instruction workflow. Use them for
steps that must not be skipped, especially context loading, per-file work, multi-phase workflows,
and verification.

```markdown
2. 🔳 Load current context
   - Read project docs if present
   - Read required references before editing

3. 🔳 Rewrite target files
   - Preserve salient information
   - Verify portable references and nixified metadata
```

## Reference Patterns

Use portable references in generated command content:

* `@references/filename.md` for command or skill bundled references
* `@skills/name/SKILL.md` for generated skill entrypoints
* `@rules/filename.md` for generated rule files
* `scope.blocks.<name>` for reusable source blocks

Avoid host-specific generated paths and old doc aliases.

## Optimization Workflow

When optimizing existing instructions:

1. **Analysis Phase**
   * Read the target source file and all linked files (`@references/`, `@skills/`, `@rules/`)
   * Identify issues: verbosity, unclear structure, weak examples, cross-file redundancy
   * Compare against current nixified authoring patterns
   * List specific issues with examples
   * Show before/after for key changes when useful
   * Estimate token savings when optimization is a goal

2. **Approval Gate**
   * Stop only when the command workflow requires approval before implementation
   * Make the required approval signal explicit in that command's content

3. **Implementation Phase**
   * Apply optimizations systematically
   * Remove meta-commentary
   * Consolidate redundant examples
   * Convert prose to lists or tables where clearer
   * Use imperative mood
   * Front-load critical rules
   * Use one emphasis level
   * Preserve all salient information
   * Keep structured fields in Nix attrs and body instructions in `content`
