---
name: pr-desc
context: fork
description: Generate detailed changelog-style summary of branch changes
model: haiku
---

# PR Description

Generate a detailed changelog-style summary of branch changes for reference. Uses project context
and branch diff to create multi-level breakdown.

## Instructions

1. 🔳 Ensure context loaded
   - Run `/ctx-load` to load project context (project doc, branch state, recent commits)

2. 🔳 Analyze changes
   - Get changed files: `jj-diff-branch --stat`
   - Read diffs for understanding: `jj-diff-branch --git`
   - Use the <deep-thinking> procedure
   - If user specified a focus area, prioritize those components

3. 🔳 Generate report
   - **High-level summary** (2-3 sentences):
     - What was the main goal/accomplishment
     - Key technical approach taken

   - **Per-component breakdown**:
     - Group changes by logical component (directory, module, or feature area)
     - For each component, list changes by category:
       - **Added**: New files, features, capabilities
       - **Changed**: Modified behavior, refactored code
       - **Fixed**: Bug fixes, corrections
       - **Removed**: Deleted files, deprecated features
     - Skip empty categories

4. 🔳 Output report
   - In **a single message**: output the complete report directly (high-level + per-component breakdown)
   - The user doesn't have access to all prior messages, you really need to verbatim include everything here
   - Never describe what was generated - show the actual content
   - This is for reference, not copy-paste
