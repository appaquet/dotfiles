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

## Instructions

Numbered steps the agent follows. Steps should be explicit about:
* What to load/search
* How to process each item
* What output to produce

## Agent Specific Checklist

Bullet list of domain-specific checks the agent performs.
```

## Description Guidelines

* Make specific and discoverable
* Describe the domain (code style, architecture, correctness)
* Include trigger phrases for when to use the agent
* Bad: "Reviews code"
* Good: "Reviews code for logic correctness, potential bugs, and runtime issues"

## Common Patterns

### Context Loading

Agents typically start by loading project context:

```markdown
1. Run the `/ctx-load` skill to load project context, branch state, and project docs. This gives you
   access to requirements and current progress.
```

### Guideline Discovery

Search for project-specific guidelines before reviewing:

```markdown
2. Search project-specific [domain] guideline files (from the root of the repository) and read
   them (ex: `**/*style*.md`, `**/*guide*.md`, etc.)
```

### Master Checklist Pattern

Create a working checklist file combining project and agent-specific rules:

```markdown
3. Create a master checklist of [domain] issues to review:
   1. For **EACH** item of the project-specific guidelines loaded in step 2
   2. For **EACH** item in agent specific check below
   3. **VERY IMPORTANT** You **MUST** include code snippets of good and bad examples for each item
   4. Write to `agent-name.local.md` in a TODO list format with the code snippets
```

### File-by-File Review

Review each changed file individually and thoroughly:

```markdown
5. For **EACH** changed file, **ONE BY ONE**:
   1. Load its diff to see the changes made to it (using `jj-diff-branch --git <file>`)
   2. Load the whole file if you don't feel you have enough context from the diff alone
   3. Load surrounding context as needed
   4. Think very hard about **EACH** rule and make sure code **STRICTLY** follows guidelines
   5. If, and only if, the code follows guidelines, move to next file
   6. If it does not, **INSERT** a `// REVIEW: agent-name - <comment>` comment
```

### REVIEW Comment Pattern

Agents insert review comments directly in code:

```markdown
**INSERT** a `// REVIEW: agent-name - <comment>` comment in the code where the issue is found.
Include description of the problem, potential consequences, and suggested fix. Don't replace any
existing code, simply add the comment.
```

### Cleanup

Remove working files after review:

```markdown
6. Remove the `agent-name.local.md` file created during the review process
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

## Agent vs Command

| Aspect | Agent | Command |
|--------|-------|---------|
| Invocation | Called by other agents/Claude | User invokes directly |
| Task tracking | Usually none (caller handles) | TaskCreate for gating |
| User interaction | Minimal - returns to caller | May use AskUserQuestion |
| Output | Structured result for caller | User-facing messages |

## Reviewer Agent Checklist Template

For code review agents, include domain-specific checks:

**Code Style**: readability, naming, formatting, comments, imports, dead code
**Architecture**: patterns, coupling, modularity, interfaces, scalability
**Correctness**: error handling, null checks, bounds, concurrency, security
