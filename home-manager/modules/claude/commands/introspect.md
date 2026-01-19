---
name: introspect
description: Reflect on an error or undesired behavior to propose instruction improvements
argument-hint: [description of issue]
---

# Introspect

Reflect on what went wrong and propose instruction changes to prevent recurrence.

Issue: `$ARGUMENTS`

## Instructions

Apply @instruction-writer best practices for all changes.

1. If issue empty, use `AskUserQuestion` to get description

2. Ultrathink: analyze conversation
   * Specific error/behavior?
   * Root cause (wrong assumption, missing context, unclear instruction)?
   * Which instruction file(s) could prevent this?

3. Summarize findings; use `AskUserQuestion` if unclear

4. Load relevant instruction files if needed

5. Draft changes **in memory** using instruction-writer skill

6. Present proposal: target file(s), before/after, rationale

**STOP** - Use `AskUserQuestion` to confirm changes.

**If approved:**
* Create jj change
* Apply changes
