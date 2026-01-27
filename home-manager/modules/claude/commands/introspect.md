---
name: introspect
description: Reflect on an error or undesired behavior to propose instruction improvements
argument-hint: [description of issue]
---

# Introspect

Reflect on what went wrong and propose instruction changes to prevent recurrence.

Issue: `$ARGUMENTS`

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. If issue empty, use `AskUserQuestion` to get description

2. Analyze the issue:
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.
   * What specific error/behavior occurred?
   * Trace back: what instruction was missing, unclear, or conflicting?
   * Which files might have related concepts? Search for them.
   * Think through each relevant instruction as a fresh agent - what could be misinterpreted?

3. Summarize findings:
   * Root cause
   * Files that need changes (including files with related concepts)
   * Conceptual changes needed

4. Use `AskUserQuestion` to confirm analysis and suggest:
   "Run `/mem-edit` to implement these changes with proper analysis workflow"

**STOP** - Do not implement changes directly. Use /mem-edit for implementation.
