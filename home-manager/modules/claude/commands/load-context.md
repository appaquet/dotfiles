---
name: load-context
description: Load comprehensive project context including docs, PR info, and branch status
---

# Load Context

Load as much context as possible about the project and task at hand.

## State

* Current branch: !`jj-current-branch`
* List of changes in current branch and stacked branches: !`jj-stacked-stats`

## Instructions

1. Read the `PR.md` file at the root of the repository:
   * The file may not exist if no task has been started yet. It may also be a markdown file included
     in the pull request, so check for this as well. Otherwise, it's fine, as it may be a new
     feature.
   * If it exists, understand current task context, requirements, and progress

2. Load relevant repository documentation:
   * Use `Glob` tool to **recursively** find:
     * `README.md`
     * `ARCHITECTURE.md`
   * Read relevant files based on the changed components that would help you understand the project
     and the task at hand.

3. Launch the branch-diff-summarizer agent to analyze and summarize branch changes:
   * Ask the agent to use the branch-diff-summarizer agent
   * The agent will check if PR.md already has file summaries and update if needed
   * This provides a detailed understanding of what changed without bloating main context

4. Synthesize and propose next steps:
   * If `PR.md` exists, propose next tasks based on TODO section
   * Propose `PR.md` updates if it's missing information like changed files or TODOs
   * If no clear direction, use `AskUserQuestion` tool for clarification on goals
   * Provide summary of current project state and context
