---
name: ctx-load
description: Load comprehensive project context including docs, project info, and branch status
---

# Load Context

Load as much context as possible about the project and task at hand.

## State

* Current branch: !`jj-current-branch`
* List of changes in current branch and stacked branches: !`jj-stacked-stats`
* Project files: !`ls "$PROJECT_ROOT/proj/" 2>/dev/null || echo "No project files"`

## Instructions

1. Find and read project docs:
   * Check if `proj/` symlink exists at repo root → find `00-*.md` main doc
   * If project instructions specify a different location, use that
   * May not exist if no task started yet - that's fine for new features.
   * If it exists, understand context, requirements, progress, and current phase
   * Load any sub-docs (`01-*.md`, `02-*.md`, ..., in same directory) if planning to work on them

2. Resolve ambiguity if multiple items in-progress:
   * If multiple tasks `[~]` or phases 🔄, use `AskUserQuestion` to clarify which to focus on
   * Mark the chosen task/phase as in-progress per @docs/project-doc.md rules

3. Synthesize and propose next steps:
   * If project doc exists, propose next tasks based on TODO section
   * Propose project doc updates if missing information
   * If no clear direction, use `AskUserQuestion` tool for clarification on goals
   * Provide summary of current project state and context
