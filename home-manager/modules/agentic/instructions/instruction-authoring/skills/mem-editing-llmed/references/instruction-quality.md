# Instruction Quality

Durable guidance for writing and editing agent instructions. Use this when the task is not merely
"where does this file live?" but "what should this instruction say so agents behave better?"

## The Quality Bar

Good instructions are operational. They change what the next agent does, skips, verifies, or refuses
to do. If a sentence does not affect behavior, routing, or validation, it is probably documentation,
not instruction.

For every addition or rewrite, be able to answer:

- Who loads this instruction: root agent, command, skill, sub-agent, or reference-on-demand?
- What decision does it influence at load time?
- What concrete failure does it prevent?
- How can the agent verify it followed the instruction?
- Where is the durable source of truth if this text should not duplicate details?

## What Belongs Where

- Root instructions: rules that apply to nearly every session and must survive context drift.
- Rules: global policy that should be loaded broadly but can stand outside the root file.
- Commands: user-invoked workflows, gates, stop points, and ordered procedures.
- Skills: activation-time judgment plus routing to focused references.
- Agents: role, scope, review/execution standard, and return contract for delegated work.
- Blocks: shared text composed by multiple sources; keep them behavior-focused, not archival.
- References: detailed frameworks, examples, or contracts loaded only when needed.

If content applies to less than half of the times a file is loaded, move it down one layer or into a
reference. If it must never be skipped, keep it in the loaded file and make it short.

## High-Leverage Patterns

### State boundaries, not aspirations

Use instructions that constrain action: what is in scope, what is out of scope, when to stop, and
what approval is required. Avoid generic quality wishes such as "be careful" unless paired with an
observable check.

Better:

```text
Before using a destructive jj operation, inspect the target change and ask the user if the content is
not provably empty.
```

Worse:

```text
Be careful with version control.
```

### Include verification, not reassurance

Every workflow instruction should say how success is proven: a command to run, rendered output to
inspect, status to report, or acceptance criteria to check. "Make sure it works" is not a test.

### Prefer stable references over copied catalogs

Instruction files should not become stale maps of every path and field. Point at stable anchors such
as `nixantic/CLAUDE.md`, nearby source files, or bundled references. Copy only the invariant that an
agent must know before deciding what to load.

### Keep examples sparse and load-bearing

Use an example only when it teaches a non-obvious distinction, such as a good boundary sentence versus
a vague one. Do not add examples that merely restate the rule.

### Make descriptions do routing work

Skill and agent descriptions are selection surfaces. Include concrete trigger phrases, file types, or
tasks the user is likely to mention. Add a negative boundary when adjacent work should not trigger the
component.

## Editing Existing Instructions

1. Read the target and its linked references before judging it.
2. Preserve the behavior contract, even when replacing the wording.
3. Remove duplication by keeping the best source and linking to it from the others.
4. Convert broad principles into operational checks where possible.
5. Keep harness-specific wording local through structured fields or `scope.forHarness`; do not fork a
   whole instruction unless behavior really differs.
6. Validate the rendered instruction when generated output changes.

## Red Flags

- A table whose main value is listing paths that are already discoverable from nearby files.
- Several paragraphs that explain history rather than current behavior.
- Multiple emphasis markers for the same rule: `CRITICAL`, `IMPORTANT`, and `MUST` stacked together.
- Negative-only instructions that never say the desired behavior.
- A checklist with no acceptance criteria or validation step.
- A reference file that must always be loaded to understand the main instruction.

## Current Authoring Invariants

- Source files return Nix data, not hand-written generated markdown or YAML frontmatter.
- Generated `CLAUDE.md`, `AGENTS.md`, command files, agent files, and `skills/*/SKILL.md` are outputs.
- Harness-specific differences belong in structured fields, harness renderers, or `scope.forHarness`.
- Portable references such as `@references/...`, `@rules/...`, and `@skills/...` are preferred over
  installed or generated absolute paths.
- Reusable product behavior belongs under `nixantic/`; AP's personal corpus belongs under
  `home-manager/modules/agentic/instructions/`.
