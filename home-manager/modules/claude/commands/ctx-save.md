---
name: ctx-save
description: Update PR.md with current project state, files, and TODO progress
---

# Save Context

Our goal is to save the current context of the project into the `PR.md` file at the root of the
repository while respecting the established structure and guidelines.

## Instructions

1. Read the current `PR.md` file at the root of the repository

2. Update the "Files" section with the current state of the project:
   * Ask the agent to use the branch-diff-summarizer agent
   * The agent will analyze all changed files and generate proper summaries
   * It will follow the established format: `- **path/to/file**: Description of file purpose. Description of changes made.`
   * Update PR.md with the agent's output for the Files section

3. Update the TODO section:
   * Mark completed tasks as `- [x]`
   * Mark ongoing tasks as `- [~]`
   * Mark incomplete tasks as `- [ ]`
   * Add any new tasks discovered during development

4. Update the context and requirements sections if needed based on new discoveries

If there are anything that you feel you should have known about the repository and the codebase, let
me know what you propose as modifications to the rules and documentation to improve the process.
