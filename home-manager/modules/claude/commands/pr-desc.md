---
name: pr-desc
context: fork
description: Generate detailed changelog-style summary of branch changes
model: haiku
---

# PR Description

Generate a detailed changelog-style summary of branch changes for reference. Uses project context
and branch diff to create multi-level breakdown.

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure context loaded | Skip if sufficient, else run /ctx-load |
| 2 | Analyze changes | diff --stat, diff --git, understand scope |
| 3 | Generate report | Changelog-style, grouped by component, with high level description |
| 4 | Output report | Full report content to user |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure context loaded** - Run `/ctx-load` to load project context (project doc, branch state, recent commits).

2. **Analyze changes**:
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Get changed files: `jj-diff-branch --stat`
   * Read diffs for understanding: `jj-diff-branch --git`
   * If user specified a focus area, prioritize those components

3. **Generate Report**:

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

4. **Output report**:
   In **a single message**: output the complete report directly (high-level + per-component
   breakdown). The user doesn't have access to all prior messages, you really need to verbatim
   include everything here. Never describe what was generated - show the actual content. This is for
   reference, not copy-paste.
