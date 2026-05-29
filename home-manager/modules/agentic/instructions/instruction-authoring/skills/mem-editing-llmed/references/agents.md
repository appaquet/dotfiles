# Agent source structure

Guidelines for authoring agent sources in the nixified instruction system.

Agent source files live under `instructions/agents/*.nix`. Each file returns plain Nix data.
Do not hand-write YAML frontmatter. `makeScope` passes the data to `mkAgent`, and the active
harness renders the generated `agents/<name>.md` file.

## Source shape

```nix
{ scope }:
{
  description = "Brief description of what the agent does and when to use it";

  model = {
    claude = "haiku";
    opencode = "anthropic/claude-haiku-4.5";
  };

  content = # markdown
    ''
      # Agent title

      ## Context

      Role definition with standards and scope.

      ## Instructions

      Numbered workflow steps. Use the Task tool for tracked work where skipping is a risk.
    '';
}
```

Fields:

* `description`: Required. Used by generated frontmatter for agent selection.
* `content`: Required. Markdown body emitted after generated frontmatter.
* `model`: Optional. Attrset keyed by harness name. If omitted, the harness default model is used.
* `context`: Optional only when supported by the relevant constructor or harness.

`name` is usually inferred from the filename by `makeScope`. Add `name` only when the generated name
must differ from the source filename.

## Description guidelines

* Make specific and discoverable.
* Describe the domain: code style, architecture, correctness, requirements, branch diffs.
* Include trigger phrases for when to use the agent.
* Bad: "Reviews code".
* Good: "Reviews code for logic correctness, potential bugs, and runtime issues".

## Harness differences

Use `scope.forHarness` for content that must differ by harness:

```nix
let
  commandName = scope.forHarness {
    claude = "/ctx-load";
    opencode = "/ctx-load";
  };
in
{
  content = ''
    Run `${commandName}` before reviewing.
  '';
}
```

Keep harness-specific wording local to the relevant field. Do not fork whole files unless the agent
behavior is genuinely different.

## Task tracking for agents

Claude sub-agents follow the top-level task-management rules: each instruction step annotated with
`🔳` becomes tracked work via the generic `Task` tool. This is Claude-specific sub-agent behavior.
Other harnesses may render the same text but use different tool implementations.

Use tracked tasks for:

* Multi-step workflows with distinct phases.
* Per-item processing across files, rules, or requirements.
* Steps where skipping is a realistic risk.

### Dynamic task creation

For per-item work, instruct agents to create tasks dynamically with the `Task` tool:

```markdown
3. 🔳 Create rule/file tasks
   - For each rule in checklist: create a Task with subject "Check: [rule]"
   - For each file to process: create a Task with subject "Process: [filename]"

4. 🔳 Execute tasks
   - For each task: mark in progress, do the work, then mark complete
```

Benefits:

* Each item becomes visible tracked work.
* Cross-file issues surface naturally when one rule is checked across all files.
* Long checklists are less likely to be skipped.

### Claude command vs sub-agent behavior

| Aspect | Command | Claude sub-agent |
|--------|---------|------------------|
| Gate | STOP and wait for user confirmation | Proceed when delegated with `🚀 Engage thrusters` |
| User interaction | Use `AskUserQuestion` when clarification is needed | Return to parent agent unless explicitly instructed otherwise |
| Task purpose | User-visible workflow tracking and gating | Internal discipline for exhaustive processing |

## Common patterns

### Context loading

Agents that need project context should run the `ctx-load` command. `ctx-load` is authored at
`instructions/commands/ctx-load.nix`; it is not a skill.

```markdown
1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Load context
   - Run `/ctx-load` for project context, branch state, and project docs
   - 🚀 Engage thrusters - As a sub-agent, proceed immediately after loading context
```

### Guideline discovery

Search for project-specific guidelines before reviewing:

```markdown
2. Search project-specific [domain] guideline files from the repository root and read them
   (examples: `**/*style*.md`, `**/*guide*.md`).
```

### REVIEW comment pattern

Agents insert review comments directly in code:

```markdown
Insert a `// REVIEW: agent-name - <comment>` comment in the code where the issue is found.
Include the problem, potential consequence, and suggested fix. Do not replace existing code.
```

### Summary pattern

Always return a summary even if no issues were found:

```markdown
Return a final summary that states what was examined. If issues were found, list each as
`file:line - brief description`. If no issues were found, say so explicitly and mention residual
testing or review gaps.
```

### Sub-agent communication

For Claude sub-agents, return results to the parent instead of notifying the user directly:

```markdown
Since you are a sub-agent, do not notify the user directly. Return the result to the parent agent;
the parent handles aggregation and user communication.
```

## Reviewer agents

Shared reviewer workflow lives in `instructions/blocks/reviewing-agent.nix`. Review agents embed it
from their `content` body:

```nix
{ scope }:
{
  description = "Reviews code for style issues, formatting, syntax errors, and code quality problems";

  content = # markdown
    ''
      # Code Style Reviewer

      ## Context

      Meticulous senior code style reviewer with exacting standards.

      ## General Guidelines

      <code-style-reviewer-guidelines>
      * Code is simple and readable
      * Errors are properly wrapped and informative
      </code-style-reviewer-guidelines>

      ## Instructions

      ${scope.blocks."reviewing-agent".embed}
    '';
}
```

Keep reviewer-specific checks in the agent file. Keep shared mechanics in the `reviewing-agent`
block so all reviewer agents stay aligned.

Reviewer checklist examples:

* Code style: readability, naming, formatting, comments, imports, dead code.
* Architecture: patterns, coupling, modularity, interfaces, scalability.
* Correctness: error handling, null checks, bounds, concurrency, security.
