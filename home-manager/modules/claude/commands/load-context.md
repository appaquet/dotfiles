---
name: load-context
description: Load comprehensive project context including docs, PR info, and branch status
tools: Read, Glob, Bash
---

Load as much context as possible about the project and task at hand.

1. Read the `PR.md` file at the root of the repository:
   * File may not exist if no task has been started yet - this is fine
   * If it exists, understand current task context, requirements, and progress

2. Load relevant repository documentation:
   * Use `Glob` tool to **recursively** find and read:
     - `README.md`
     - `ARCHITECTURE.md`
   * If `PR.md` exists with a "Files" section, focus on those relevant areas

3. Analyze current branch status:
   * Use `jj-stacked-stats` to list all changed files and understand branch structure
   * Determine if we're on a stacked branch or standalone branch

4. Load GitHub PR information:
   * Get current branch name: `jj-current-branch`
   * Load PR details: `gh pr view $(jj-current-branch)`
   * Analyze PR description and comments if they exist
   * **Important**: Use branch name explicitly since jj uses detached head

5. Synthesize and propose next steps:
   * If `PR.md` exists, propose next tasks based on TODO section
   * If no clear direction, ask for clarification on goals
   * Provide summary of current project state and context

6. Notify completion with `notify "Context loaded"`
