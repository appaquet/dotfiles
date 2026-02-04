---
name: introspect
description: Reflect on an error or undesired behavior to propose instruction improvements
argument-hint: [description of issue]
---

# Introspect

Reflect on what went wrong and propose instruction changes to prevent recurrence.

Issue: `$ARGUMENTS`

## Instructions

1. If issue empty, use `AskUserQuestion` to get description

2. Analyze the issue:
   * Use the <deep-thinking> procedure
   * What specific error/behavior occurred?
   * Trace back: what instruction was missing, unclear, or conflicting?
   * Which files might have related concepts? Search for them

3. Summarize findings:
   * Root cause
   * Files that need changes (including files with related concepts)
   * Conceptual changes needed

4. Use `AskUserQuestion` to confirm analysis and suggest:
   "Run `/mem-edit` to implement these changes with proper analysis workflow"

**STOP** - Do not implement changes directly. Use /mem-edit for implementation.
