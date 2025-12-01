---
name: ctx-save
description: Update PR.md with current project state, files, and TODO progress
---

# Save Context

Save current project context into `PR.md` while respecting established structure.

## Instructions

1. Find `PR.md` (check root symlink → follow to actual location, or per project instructions).
   Also identify any phase sub-files (`PR-<phase-name>.md` in same directory).

2. Update the "Files" section with the current state of the project:
   * Ask the agent to use the branch-diff-summarizer agent
   * The agent will analyze all changed files and generate proper summaries
   * It will follow the established format: `- **path/to/file**: Description of file purpose. Description of changes made.`
   * Update PR.md with the agent's output for the Files section

3. Update the TODO section in both `PR.md` and current phase sub-file (if working on a phase):
   * Mark completed tasks as `- [x]`
   * Mark ongoing tasks as `- [~]`
   * Mark incomplete tasks as `- [ ]`
   * Add any new tasks discovered during development
   * Keep both files in sync

4. Update context and requirements sections if needed based on new discoveries

If there are anything that you feel you should have known about the repository and the codebase, let
me know what you propose as modifications to the rules and documentation to improve the process.
