---
name: ctx-save
description: Update project doc with current state, files, and TODO progress
---

# Save Context

Save current project context into project docs while respecting established structure.

## Instructions

1. Find project docs (check `proj/` symlink → find `00-*.md` main doc).
   Also identify any sub-docs (`01-*.md`, `02-*.md`, ..., in same directory).

2. Update the "Files" section:
   * Launch the `branch-diff-summarizer` agent to analyze changed files
   * Update project doc with agent's output (format per @docs/project-doc.md)

3. Update the TODO section (format per @docs/project-doc.md):
   * Update task and phase status in both main doc and current sub-doc
   * Add any new tasks discovered during development
   * Phase transitions: use `AskUserQuestion` before changing phase status

4. Update context and requirements sections if needed based on new discoveries

If there are anything that you feel you should have known about the repository and the codebase, let
me know what you propose as modifications to the rules and documentation to improve the process.
