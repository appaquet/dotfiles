---
name: introspect
description: Reflect on an error or undesired behavior to propose instruction improvements
argument-hint: [description of issue]
---

# Introspect

Reflect on what went wrong and propose instruction changes to prevent recurrence.

Issue: `$ARGUMENTS`

## Instructions

**DO NOT MODIFY FILES** until Phase 4.

1. If issue empty, use `AskUserQuestion` to get description of what went wrong
2. Ultrathink: analyze what happened in this conversation
   - What was the specific error or undesired behavior?
   - What was the root cause (wrong assumption, missing context, unclear instruction)?
   - Which instruction file(s) could prevent this?
3. Summarize findings to user
4. Use `AskUserQuestion` if root cause unclear or need more info
5. Load relevant instruction files if not in context
6. Use instruction-writer skill to draft changes
7. Present proposal: target file(s), before/after, rationale

**STOP** - Use `AskUserQuestion` to confirm user wants to apply changes

1. Create empty jj change (if not already in one)
2. Apply changes
