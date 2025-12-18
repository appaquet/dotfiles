---
name: ctx-save
description: Update project doc with current state, files, and TODO progress
---

# Save Context

Save current project context into project docs while respecting established structure.

## Instructions

1. Find project docs (check `proj/` symlink → find `00-*.md` main doc).
   Also identify any sub-docs (`01-*.md`, `02-*.md`, ..., in same directory).

2. Update the "Files" section with the current state of the project:
   * Ask the agent to use the branch-diff-summarizer agent
   * The agent will analyze all changed files and generate proper summaries
   * It will follow the established format: `- **path/to/file**: Description of file purpose. Description of changes made.`
   * Update project doc with the agent's output for the Files section

3. Update the TODO section in both main doc and current sub-doc (if working on a phase):
   * Mark completed tasks as `- [x]`
   * Mark ongoing tasks as `- [~]`
   * Mark incomplete tasks as `- [ ]`
   * Add any new tasks discovered during development
   * Keep both files in sync

4. Update context and requirements sections if needed based on new discoveries

If there are anything that you feel you should have known about the repository and the codebase, let
me know what you propose as modifications to the rules and documentation to improve the process.
