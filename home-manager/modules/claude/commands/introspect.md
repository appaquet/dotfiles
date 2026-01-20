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

2. Load instruction-writer skill

3. Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!):
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.
   * What specific error/behavior occurred?
   * Trace back: what instruction was missing, unclear, or conflicting?
   * Which files might have related concepts? Search for them.
   * Think through each relevant instruction as a fresh agent - what could be misinterpreted?

4. Summarize findings:
   * Root cause
   * Files that need changes (including files with related concepts)
   * Conceptual changes needed

5. Use `AskUserQuestion` to confirm analysis and suggest:
   "Run `/mem-edit` to implement these changes with proper analysis workflow"

**STOP** - Do not implement changes directly. Use /mem-edit for implementation.
