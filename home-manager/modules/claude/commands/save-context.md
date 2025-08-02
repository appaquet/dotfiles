---
name: save-context
description: Update PR.md with current project state, files, and TODO progress
---

Our goal is to save the current context of the project into the `PR.md` file at the root of the
repository while respecting the established structure and guidelines.

1. Read the current `PR.md` file at the root of the repository

2. Update the "Files" section with the current state of the project:
   * Use `jj-diff-branch --stat` to get the list of modified files in the current branch
   * Include any files that are not necessarily modified but are very important or relevant for the task
   * Follow the established format: `- **path/to/file**: Description of file purpose. Description of changes made.`

3. Update the TODO section:
   * Mark completed tasks as `- [x]`
   * Mark ongoing tasks as `- [~]`
   * Mark incomplete tasks as `- [ ]`
   * Add any new tasks discovered during development

4. Update the context and requirements sections if needed based on new discoveries

5. Notify completion with `notify "Context saved"`

If there are anything that you feel you should have known about the repository and the codebase, let
me know what you propose as modifications to the rules and documentation to improve the process.
