# Agent Structure

Guidelines for writing Claude Code agents (subagents).

## Agent Structure

```yaml
---
name: agent-name
description: Brief description of what the agent does and when to use it
---

# Agent Title

## Context

Role definition with personality traits and standards. Agents often use emphatic language
to reinforce thoroughness ("uncompromising standards", "ruthlessly pedantic", "fanatically
pedantic").

## Task Tracking

Task tracking table for complex agents (see below).

## Instructions

Numbered steps the agent follows. Steps should be explicit about:
* What to load/search
* How to process each item
* What output to produce

## Agent Specific Checklist

Bullet list of domain-specific checks the agent performs, wrapped in XML tags for referencing.
```

## Description Guidelines

* Make specific and discoverable
* Describe the domain (code style, architecture, correctness)
* Include trigger phrases for when to use the agent
* Bad: "Reviews code"
* Good: "Reviews code for logic correctness, potential bugs, and runtime issues"

## Task Tracking for Agents

Complex agents (especially reviewers) benefit from task tracking to ensure thoroughness.

### When to Use Task Tracking

* Multi-step workflows with distinct phases
* Per-item processing (files, rules, requirements)
* Agents where skipping steps is a risk

### Rules-as-Tasks Pattern (Recommended for Reviewers)

Instead of file-by-file review, use rule-by-rule review with tasks:

```markdown
## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Load project context | Run /ctx-load for requirements and progress |
| 2 | Search guidelines | Find project-specific guideline files |
| 3 | Load changed files | Get file list, load all diffs upfront |
| 4 | Create rule tasks | **FIRST**: Read guidelines + embedded checklist. **THEN**: For each rule, create `TaskCreate` with subject "Check: [rule]" and description with good/bad examples. |
| 5 | Execute rule checks | For each Check task: examine ALL files for this issue, insert REVIEW comments, mark complete |
| 6 | Cross-file synthesis | Look for patterns spanning multiple files |
| 7 | Return summary | Comprehensive summary even if no issues |
```

**Benefits of rules-as-tasks:**
* Each rule becomes a task that can't be skipped
* Cross-file issues surface naturally (checking "coupling" across all files at once)
* Prevents checklist fatigue (one rule at a time, thoroughly)
* No intermediate .local.md file needed - tasks ARE the checklist

### Files-as-Tasks Pattern (For Summarizers)

For agents that process files individually (not checking rules):

```markdown
| 3 | Create file tasks | **FIRST**: Get file list. **THEN**: For each file, create `TaskCreate` with subject "Summarize: [filename]" |
| 4 | Process files | For each task: process file, mark complete |
```

### Key Differences from Commands

| Aspect | Command | Agent |
|--------|---------|-------|
| Gate tasks | "Await /go to proceed" | None (🚀 Engage thrusters) |
| User interaction | AskUserQuestion | Return to caller |
| Task purpose | User visibility + gating | Internal discipline |

## Common Patterns

### Context Loading

Agents typically start by loading project context:

```markdown
1. Run the `/ctx-load` skill to load project context, branch state, and project docs. This gives you
   access to requirements and current progress.

🚀 Engage thrusters - As a sub-agent, proceed immediately after loading context.
```

### Guideline Discovery

Search for project-specific guidelines before reviewing:

```markdown
2. Search project-specific [domain] guideline files (from the root of the repository) and read
   them (ex: `**/*style*.md`, `**/*guide*.md`, etc.)
```

### REVIEW Comment Pattern

Agents insert review comments directly in code:

```markdown
**INSERT** a `// REVIEW: agent-name - <comment>` comment in the code where the issue is found.
Include description of the problem, potential consequences, and suggested fix. Don't replace any
existing code, simply add the comment.
```

### Comprehensive Summary

Always return a summary even if no issues found:

```markdown
**IMPORTANT**: Always return a comprehensive summary of your review, even if you added review
comments to the code. Even if no issues are found, you MUST identify areas for improvement.
If truly no issues exist, provide a detailed explanation of what was examined.
```

### Sub-agent Communication

If agent is a sub-agent, don't notify user directly:

```markdown
Since you're a sub-agent, **NEVER** notify the user of the completion of your task. This will be
done via the parent agent. Just return the result as specified.
```

## Reviewer Agent Checklist Template

For code review agents, include domain-specific checks wrapped in XML tags:

```markdown
## Agent Specific Checklist

<agent-name-checklist>
* Rule 1
* Rule 2
...
</agent-name-checklist>
```

**Code Style**: readability, naming, formatting, comments, imports, dead code
**Architecture**: patterns, coupling, modularity, interfaces, scalability
**Correctness**: error handling, null checks, bounds, concurrency, security
