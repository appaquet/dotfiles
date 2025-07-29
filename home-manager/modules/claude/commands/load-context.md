---
name: load-context
description: Load comprehensive project context including docs, PR info, and branch status
tools: Read, Glob, Bash
---

Load as much context as possible about the project and task at hand.

1. Read the `PR.md` file at the root of the repository:
   * The file may not exist if no task has been started yet. It may also be a markdown file included
     in the pull request, so check for this as well. Otherwise, it's fine, as it may be a new
     feature.
   * If it exists, understand current task context, requirements, and progress

2. Load relevant repository documentation:
   * Use `Glob` tool to **recursively** find and read:
     * `README.md`
     * `ARCHITECTURE.md`
   * If `PR.md` exists with a "Files" section, focus on those relevant areas

3. Analyze current branch status:
   * Use `fish -c "jj-stacked-stats"` to list all changed files in the current branch, as well as in other
     stacked branches at the base of this one if it is part of a stack of branches.
   * Use can use `fish -c "jj-diff-branch"` to see the diff of the current branch against the previous branch

4. Load GitHub PR information:
   * Get current branch name: `fish -c "jj-current-branch"`
   * Load PR details: `gh pr view $(fish -c "jj-current-branch")`
   * Analyze PR description and comments if they exist
   * **Important**: Use branch name explicitly since jj uses detached head

5. Synthesize and propose next steps:
   * If `PR.md` exists, propose next tasks based on TODO section
   * If no clear direction, ask for clarification on goals
   * Provide summary of current project state and context
