# Instruction source structure

Guidelines for root instruction files, rule instruction sources, reusable blocks, and structured
prompting in the nixified instruction system.

All authored instruction sources under `~/dotfiles/home-manager/modules/agentic/instructions/`
return plain Nix attrsets. Constructors are called centrally from `makeScope` in `tooling.nix`.
Do not edit generated output and do not hand-write YAML frontmatter in Nix sources.

## Structured prompting

Claude 4.x was trained to understand XML tags as cognitive containers, not just code. Proper
structure improves output quality. These patterns are still useful in harness-neutral source content
when the generated markdown will be read by LLM agents.

### Basic prompt structure

For task-oriented prompts, use: **[Role] + [Task] + [Context]**

```text
[Role]: You are a code reviewer specializing in security.
[Task]: Review this authentication module for vulnerabilities.
[Context]: This is a Node.js Express app using JWT tokens. Focus on token validation and session handling.
```

This structure front-loads the task before background information.

### XML tags vs Markdown headers

Use XML tags when:

* Complex multi-part tasks need explicit boundaries.
* Constraints must be enforced as validation rules.
* Adjacent sections could bleed into each other.
* Examples need sharp good/bad separation.

Use Markdown headers when:

* The structure is simple and linear.
* Humans need to scan the generated markdown.
* The file has one clear purpose.
* Content flows naturally between sections.

### Tag hierarchy and priority

Outer tags receive higher priority weighting. Put critical constraints at outer levels and details
inside nested sections:

```xml
<task>
  <constraints>
    Never exceed 100 words
    Output must be valid JSON
  </constraints>
  <context>
    Additional details and background...
  </context>
</task>
```

### Content isolation

Separate tags prevent context contamination better than narrative comparisons:

```xml
<good-example>
Concise, explicit instruction that triggers correct behavior
</good-example>

<bad-example>
Verbose, vague instruction that leads to confusion
</bad-example>
```

### Constraint and validation tags

Validation rules inside tags become more enforceable:

```xml
<output-format>
  <validation>
    - Must be valid JSON
    - Array length between 1 and 10
    - Each item under 50 characters
  </validation>
</output-format>
```

### Basic structure pattern

```xml
<background-information>
Context about the system and conventions
</background-information>

<instructions>
Step-by-step tasks to perform
</instructions>

<examples>
Canonical examples demonstrating expected behavior
</examples>
```

Benefits:

* Helps the model parse intent.
* Separates context, instructions, and examples.
* Reduces repeated prose by giving sections clear boundaries.

## Root instruction file structure

The root instruction source is `instructions/instructions/main.nix`. It returns data consumed by
`mkInstructions`, which generates the harness root file: `CLAUDE.md` for Claude or `AGENTS.md` for
OpenCode.

```nix
{ scope }:
let
  outputPath = scope.forHarness {
    claude = "CLAUDE.md";
    opencode = "AGENTS.md";
  };
in
{
  heading = "Instructions";
  content = ''
    * Name: AP

    ${scope.blocks."top-level-instructions".embed}
    ${scope.blocks."sub-agents-workflows".embed}
  '';
  inherit outputPath;
}
```

Root content should cover:

* What environment and workflow assumptions apply globally.
* Why high-priority behavioral rules exist when that context prevents misinterpretation.
* How agents should execute recurring workflows, including context loading and task tracking.

Keep detailed reusable policy in blocks or rule sources. The root source should compose the highest
salience global instructions with `${scope.blocks."name".embed}` instead of duplicating long sections.

## Source layout

Current authoring layout:

```text
instructions/
  tooling.nix                         # constructors and makeScope
  frontmatter.nix                     # shared frontmatter renderer
  harnesses/
    claude.nix                        # Claude field selection
    opencode.nix                      # OpenCode field selection
  blocks/
    reviewing-agent.nix               # reusable block data -> mkBlock
  agents/
    code-style-reviewer.nix           # data -> mkAgent -> agents/<name>.md
  commands/
    ctx-load.nix                      # data -> mkCommand -> commands/<name>.md
  skills/
    mem-editing/
      default.nix                     # data -> mkSkill -> skills/mem-editing/SKILL.md
      references/
        agents.md                     # copied raw as a skill subfile
  instructions/
    main.nix                          # data -> mkInstructions -> root file
    rules/
      development.nix                 # data -> mkInstructions -> rules/development.md
```

Constructor mapping:

* `instructions/blocks/*.nix` returns block data and is wrapped by `mkBlock`.
* `instructions/agents/*.nix` returns agent data and is wrapped by `mkAgent`.
* `instructions/commands/*.nix` returns command data and is wrapped by `mkCommand`.
* `instructions/skills/<name>/default.nix` returns skill data and is wrapped by `mkSkill`.
* `instructions/skills/<name>/references/*.md` is copied raw as skill subfiles.
* `instructions/instructions/main.nix` returns instruction data and is wrapped by `mkInstructions`.
* `instructions/instructions/rules/*.nix` returns instruction data and is wrapped by `mkInstructions`.

## Do not edit generated output

Generated markdown is produced from the Nix sources. Hand-author the Nix template content, then build
or deploy through the normal Home Manager flow. Do not edit generated `CLAUDE.md`, `AGENTS.md`,
`agents/*.md`, `commands/*.md`, or generated `skills/*/SKILL.md` directly.

Frontmatter belongs to harness renderers. Source files provide structured fields such as
`description`, `argumentHint`, `model`, `effort`, `context`, `agent`, `allowedTools`, and `subtask`.
Each harness decides which fields to render.

## Rule instruction sources

Rule sources live under `instructions/instructions/rules/*.nix`. They use the same `mkInstructions`
shape as the root source:

```nix
{ scope }:
{
  heading = "Development Instructions";
  content = ''
    ## General principles

    * Never implement until the required proceed signal is present.
    * Follow existing patterns and libraries.
  '';
}
```

Use rules for global policies that should be generated as separate `rules/*.md` files. Claude may
auto-load rule files from its generated rules directory depending on harness configuration. Treat that
as Claude-specific behavior, not a property of the source system itself.

## Skill reference files

Skill reference files live under `instructions/skills/<name>/references/*.md`. Markdown reference
files are copied raw as skill subfiles and are loaded on demand from the generated skill.

Use portable references from skill content:

* `@references/filename.md` for files inside the same skill directory.
* `@skills/name/SKILL.md` for another generated skill.
* `@rules/filename.md` for generated rule files.

Example from a skill source:

```nix
{ scope }:
{
  description = "Instructions to use when instruction files need to be changed.";
  content = ''
    # Instruction editing guidelines

    Load supporting files as needed:

    - @references/agents.md: Agent source structure and patterns
    - @references/instructions.md: Root and rule instruction source structure
    - @rules/development.md: Development workflow rules
  '';
}
```

Do not use absolute generated paths in source content unless a harness explicitly requires them.
Prefer portable references so the same source works for Claude and OpenCode.

## Blocks

Blocks live under `instructions/blocks/*.nix`. They are reusable data fragments wrapped by `mkBlock`.

Block shape:

```nix
{ scope }:
{
  heading = "Code Review Agent Guidelines";
  content = ''
    Shared workflow text.
  '';
}
```

Supported fields:

* `heading`: Optional. When present, embedded output starts with `## <heading>`.
* `content`: Required. Markdown body.
* `tag`: Optional. Adds an XML tag wrapper in the rendered block.
* `taggedContent`: Optional. Overrides what goes inside the XML tag when `tag` is set.

Embed blocks from other sources with `${scope.blocks."block-name".embed}`. Example reviewer agents
embed `${scope.blocks."reviewing-agent".embed}` from `instructions/blocks/reviewing-agent.nix`.

## Harness-specific content

Use `scope.forHarness` when content or output paths differ by harness:

```nix
scope.forHarness {
  claude = "CLAUDE.md";
  opencode = "AGENTS.md";
}
```

Use this for true harness differences only. Keep shared behavior in common content, and let harness
frontmatter renderers handle field-level output differences.
