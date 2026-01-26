# Instruction Writing Best Practices for Claude 4.x

Comprehensive guidelines for writing effective instructions, skills, slash commands, and memory files for Claude Code.

## Core Philosophy

### Self-Verification (Highest Leverage)

**Give Claude ways to verify its work.** This is the single highest-leverage technique for instruction quality.

* Include tests, expected outputs, or success criteria in instructions
* Add verification steps at the end of workflows ("Run X to confirm Y")
* Provide screenshots or examples of correct output for UI work
* Define what "done" looks like explicitly

<good-example>
After implementing, run `npm test` and verify all tests pass. The output should show "42 passing, 0 failing".
</good-example>

<bad-example>
Implement the feature and make sure it works.
</bad-example>

### Minimal, High-Signal Information

**Find the smallest set of high-signal tokens that maximize desired outcomes.** Every token depletes the model's attention budget.

* Start with minimal prompt using best available model
* Add clarity and examples based on observed failures
* Don't anticipate every edge case upfront
* Remove meta-commentary and verbose explanations

**Instruction Budget**: LLMs reliably follow only 150-200 instructions. Claude Code's system prompt uses ~50, so CLAUDE.md should stay well under 150 instructions.

**Line Count**: Keep CLAUDE.md under 300 lines; under 60 lines is optimal. Put detailed docs in separate files.

### Front-Load Critical Instructions

Put the most important instruction at the very top. Claude processes instructions sequentially; early content gets more attention weight.

* State the task clearly before providing context
* Critical constraints go before background information
* Structure: [Role/Task] → [Constraints] → [Context] → [Examples]

### Provide Context and Motivation

Explain *why* instructions matter—helps Claude understand goals.

**Good**: "Your response will be read aloud by text-to-speech engine, so never use ellipses since the engine won't know how to pronounce them."

**Bad**: "NEVER use ellipses."

### Universal Applicability

CLAUDE.md loads in every conversation. Include only instructions that apply to most tasks.

* Move task-specific guidance to separate files Claude reads on-demand
* If instruction applies to <50% of sessions, it doesn't belong in CLAUDE.md
* The more irrelevant content, the more Claude filters out everything uniformly

### Hooks vs Instructions

**Hooks** are shell commands that execute automatically on events (PreToolUse, PostToolUse, etc.). Use hooks instead of instructions when:

* **Action must happen every time with zero exceptions** - hooks enforce mechanically, instructions can be ignored
* **Claude already does it correctly without instruction** - delete the instruction, the behavior is trained-in
* **Instruction is frequently ignored** - convert to hook for enforcement

**Keep as instructions when:**
* Behavior requires judgment or context-sensitivity
* Action varies based on situation
* Hook implementation would be complex or brittle

**Pruning strategy:** If Claude consistently follows a rule without the instruction, remove it. Instructions that duplicate trained-in behavior waste attention budget.

## Structured Prompting

Claude 4.x was trained to understand XML tags as cognitive containers, not just code. Proper structure significantly improves output quality.

### Basic Prompt Structure

For task-oriented prompts, use: **[Role] + [Task] + [Context]**

```
[Role]: You are a code reviewer specializing in security.
[Task]: Review this authentication module for vulnerabilities.
[Context]: This is a Node.js Express app using JWT tokens. Focus on token validation and session handling.
```

This structure front-loads the task (what to do) before context (background information).

### XML Tags vs Markdown Headers

**Use XML tags when**:
* Complex multi-part tasks requiring explicit boundaries
* Constraints that must be enforced (validation rules)
* Preventing context bleed between sections
* Chain-of-thought reasoning needs exposure

**Use Markdown headers when**:
* Simple, linear structure
* Human-readable documentation
* Single-purpose files
* Content flows naturally between sections

### Tag Hierarchy and Priority

Outer tags receive higher priority weighting. Structure critical constraints at outer levels, details nested within:

```xml
<task>
  <constraints>  <!-- High priority - processed first -->
    Never exceed 100 words
    Output must be valid JSON
  </constraints>
  <context>  <!-- Lower priority - provides background -->
    Additional details and background...
  </context>
</task>
```

### Content Isolation

Separate tags prevent context contamination. Better than narrative comparisons:

```xml
<good_example>
Concise, explicit instruction that triggers correct behavior
</good_example>

<bad_example>
Verbose, vague instruction that leads to confusion
</bad_example>
```

### Constraint and Validation Tags

Validation rules within tags become enforceable constraints:

```xml
<output_format>
  <validation>
    - Must be valid JSON
    - Array length between 1-10
    - Each item under 50 characters
  </validation>
</output_format>
```

### Basic Structure Pattern

```xml
<background_information>
Context about the system and conventions
</background_information>

<instructions>
Step-by-step tasks to perform
</instructions>

<examples>
Canonical examples demonstrating expected behavior
</examples>
```

Benefits:
* Helps model parse intent effectively
* Separates concerns (context vs. instructions vs. examples)
* Improves token efficiency through clear boundaries

## Writing Style

### Be Explicit and Direct

Claude 4.x excels with clear, specific instructions.

**System prompt sensitivity**: Claude 4.x is highly responsive to system prompts. Dial back aggressive language—where you might have said "CRITICAL: You MUST...", use normal prompting like "Use this tool when...".

**Good**: "Include as many relevant features and interactions as possible. Go beyond basics to create fully-featured implementation."

**Bad**: "Create an analytics dashboard" (too vague)

### Action Language

* Use "Change X" not "Can you suggest changes to X"
* Default to imperative mood: "Do X" not "You should do X"
* Avoid tentative phrasing: "Fix the bug" not "Maybe you could look at fixing the bug"

### Reverse Negatives

**Bad**: "Don't use markdown"

**Good**: "Write in clear, flowing prose using complete paragraphs and sentences"

### Match Style to Output

The formatting style of your prompt influences response formatting.

* Remove markdown from prompts to reduce markdown in responses
* Use prose in prompts to encourage prose in responses
* "Write in prose rather than lists unless presenting truly discrete items where list format is best option"

### Minimize Verbosity

Claude 4.5 is naturally concise. Reinforce when needed:

* "Provide fact-based progress reports without unnecessary verbosity"
* "No superlatives or excessive praise"
* "Never say 'You're absolutely right!' - just do the work"

## Examples

### Canonical Examples Over Edge Cases

Provide diverse, representative examples rather than exhaustive exception lists.

**Key Guidelines**:

* Claude 4.x pays close attention to details in examples
* Ensure examples align perfectly with desired behaviors
* Models are highly sensitive to subtle patterns in examples
* 1-2 well-chosen examples better than many redundant ones

**Format**:

```xml
<example>
User: [realistic user input]
Assistant: [ideal response demonstrating all principles]
</example>
```

Or contrast good vs. bad:

```xml
<good-example>
Concise, explicit instruction that triggers correct behavior
</good-example>

<bad-example>
Verbose, vague instruction that leads to confusion
</bad-example>
```

### Scrutinize Your Examples

* Do they demonstrate the exact behavior you want?
* Are there subtle patterns that could mislead?
* Do they cover the most common use cases (not rare edge cases)?

## Instruction Types

### CLAUDE.md Structure

**WHY, WHAT, HOW**:
* **WHAT**: Tech stack, project structure, monorepo layout
* **WHY**: Project purpose, component functions, design rationale
* **HOW**: Build commands, test procedures, verification steps

**Progressive Disclosure**:

Create a docs directory for detailed information:

```
agent_docs/
  ├─ building.md
  ├─ testing.md
  ├─ conventions.md
  └─ architecture.md
```

CLAUDE.md points to these files; Claude reads relevant ones per-task.

**What NOT to Include**:

* Don't auto-generate via `/init`. Each line affects every interaction—manually craft content.
* Don't embed code snippets. Prefer `file:line` references over code copies. Snippets become outdated; references stay accurate.

### Skills (SKILL.md)

```yaml
---
name: skill-name-here
description: Specific capability with trigger phrases. Include file types, concrete capabilities, and natural phrases users would say. Keep under 1024 chars.
---

# Skill Title

Brief purpose statement.

## When to Use

Specific triggers and scenarios.

## Core Principles

Key guidelines (reference supporting docs with @filename.md).

## Workflow

Clear steps for different scenarios.

## Supporting Files

* @referenced-file.md: Purpose
```

**Description Guidelines**:

* Make specific and discoverable
* Include file types/formats (PDF, .xlsx, etc.)
* List concrete capabilities
* Specify trigger phrases users would naturally say
* Bad: "Helps with documents"
* Good: "Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDFs or mentioning document extraction."

**SKILL.md vs Supporting Files**:

Claude Code uses **progressive disclosure** - SKILL.md loads on activation, supporting files load only when referenced.

**SKILL.md should contain**:
* Quick-start guidance Claude needs immediately
* Essential instructions and workflow steps
* Concrete usage examples
* References to supporting files with @filename.md

**Supporting files handle**:
* Extended documentation (best-practices.md, reference.md)
* Additional examples (examples.md)
* Detailed API specifications
* Utility scripts and templates

**Avoiding Duplication**:
* Keep detailed principles in supporting files
* SKILL.md provides brief overview with cross-references
* Example: "Apply principles from @best-practices.md" instead of repeating them
* Pattern: "For detailed X, see @reference.md"

### Slash Commands

```markdown
---
name: command-name
description: Brief one-line purpose
argument-hint: [optional-arg]
---

# Command Title

Clear purpose statement.

Target: $ARGUMENTS (if applicable)

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure X loaded | Skip if already done, else do X |
| 2 | Do main work | Details for agent |
| 3 | Await /go to proceed | Work complete, await user confirmation |

## Instructions

1. **Ensure X loaded** - Skip if already done.
2. **Do main work** - Details...
3. **Await /go to proceed** - Stop and wait for user.
```

**Task Tracking Guidelines**:

* **Create ALL tasks first** - One `TaskCreate` per table row BEFORE any other work
* **Subject** = user-visible in task list UI (concise, actionable)
* **Description** = agent context only (can be verbose)
* Use **validation phrasing** for skippable tasks: "Ensure X" not "Do X"
* Gate tasks use "Await /go to proceed" (not "STOP" - meaningless to user)
* Dynamic tasks created at runtime: "For each X found, add sub-task 'Fix: [description]'"
* Number steps match between table and instructions for clarity

**Command Guidelines**:

* Front-load critical rules (STOP points, approval gates)
* Use phases for multi-step workflows
* Single emphasis level (CRITICAL or Important, not both)
* Imperative mood throughout

### Memory Files (docs/*.md)

```markdown
# Section Title

Brief context.

## Subsection

* Concise bullet points
* Avoid prose where lists suffice
* One emphasis level (CRITICAL for critical items)

## Examples

<example>
User: scenario
Assistant: ideal response
</example>

## Important Notes

* Front-load critical rules
* Reference other docs: @~/.claude/docs/filename.md
```

## Quality & Reliability

### Prevent Hallucinations

"Never speculate about code you have not opened. If the user references a specific file, read the file before answering."

### Avoid Hard-Coding

"Implement general-purpose solutions using standard tools, not workarounds tailored to specific test cases."

### Token Budget Awareness

"Your context window will be automatically compacted as it approaches its limit, allowing you to continue working indefinitely."

### Tool Design Principles

For skills that use tools:

* Tools should be self-contained and robust to error
* Avoid overlapping tool functionality
* Curated minimal viable set enables better maintenance
* Use `allowed-tools` to restrict access when appropriate

## Optimization Workflow

When optimizing existing instructions:

1. **Analysis Phase**
   * Read target file and all linked files (@docs references)
   * Identify issues: verbosity, unclear structure, weak examples, cross-file redundancy
   * Compare against these best practices
   * List specific issues with examples
   * Show before/after for key changes
   * Estimate token savings

2. **Wait for Approval**

3. **Implementation Phase**
   * Apply optimizations systematically
   * Remove meta-commentary
   * Consolidate redundant examples
   * Convert prose to lists/tables where clearer
   * Use imperative mood
   * Front-load critical rules
   * Single emphasis level
   * **Preserve all salient information**

## Common Anti-Patterns

❌ **Verbose explanations**: "It is important to note that you should..."
✅ **Direct**: "Use X for Y"

❌ **Multiple emphasis**: "CRITICAL: Important: Note that..."
✅ **Single level**: "Do X" (Claude 4.x rarely needs CRITICAL)

❌ **Tentative language**: "You might want to consider..."
✅ **Imperative**: "Do X"

❌ **Many redundant examples**: 5 examples of the same pattern
✅ **Canonical examples**: 1-2 diverse, representative examples

❌ **Prose for discrete items**: "First do this, then do that, and after that..."
✅ **Lists for steps**: "1. Do this\n2. Do that"

❌ **Vague descriptions**: "Helps with files"
✅ **Specific descriptions**: "Parse CSV files, convert to JSON, handle encoding. Use when working with CSV data."

❌ **Split numbered lists across headers**: Headers break list continuity
```markdown
### Phase 1
1. Step one
### Phase 2
2. Step two  <!-- invalid: restarts at 1 in rendered markdown -->
```
✅ **Continuous list with inline phases or separate lists per section**

## References

* [Claude 4.x Best Practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices)
* [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
* [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills.md)
* [Writing a Good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
