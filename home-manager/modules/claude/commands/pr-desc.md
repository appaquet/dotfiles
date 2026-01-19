---
name: pr-desc
description: Generate detailed changelog-style summary of branch changes
context: fork
argument-hint: [focus-area]
---

# PR Description

Generate a detailed changelog-style summary of branch changes for reference. Uses project context
and branch diff to create multi-level breakdown.

Focus: $ARGUMENTS

## Instructions

1. Run `/ctx-load` to load project context (project doc, branch state, recent commits).

2. Analyze branch changes:
   * Get changed files: `jj-diff-branch --stat`
   * Read diffs for understanding: `jj-diff-branch --git`
   * If user specified a focus area, prioritize those components

3. Generate changelog-style summary:

   **High-level summary** (2-3 sentences):
   * What was the main goal/accomplishment
   * Key technical approach taken

   **Per-component breakdown**:
   * Group changes by logical component (directory, module, or feature area)
   * For each component, list changes by category:
     * **Added**: New files, features, capabilities
     * **Changed**: Modified behavior, refactored code
     * **Fixed**: Bug fixes, corrections
     * **Removed**: Deleted files, deprecated features
   * Skip empty categories

4. Write to project doc "Pull Requests" section (create if missing).

5. Present summary to user - this is for reference, not copy-paste into PR.
