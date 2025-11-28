---
name: ctx-load
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
   * If it exists, determine which phase we are working on and what remains to be done
     Load any sub-files referenced by the file if we're planning to work on them next

2. Launch the `branch-diff-summarizer` agent to analyze and summarize branch changes:
   * Ask the agent to use the branch-diff-summarizer agent
   * The agent will check if PR.md already has file summaries and update if needed
   * This provides a detailed understanding of what changed without bloating main context

3. Synthesize and propose next steps:
   * If `PR.md` exists, propose next tasks based on TODO section
   * Propose `PR.md` / `PR-<subphase>.md` updates if it's missing information like changed files or
     TODOs
   * If no clear direction, use `AskUserQuestion` tool for clarification on goals
   * Provide summary of current project state and context
