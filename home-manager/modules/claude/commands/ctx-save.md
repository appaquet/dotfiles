---
name: ctx-save
description: Update project doc with current state, files, and Tasks progress
---

# Save Context

Save project state for easy resumption by you or another agent.

Project files: !`claude-proj-docs`

## Instructions

1. Find project docs: `proj/` symlink → `00-*.md` main doc, plus any sub-docs (`01-*.md`, etc.)

2. Update Files section:
   * Run `branch-diff-summarizer` agent for changed files
   * Update with output (format per @docs/project-doc.md)

3. Update Tasks section:
   * Mark completed tasks `[x]`
   * Add new tasks discovered during work
   * If all tasks under a phase are `[x]` → ask user if phase should be ✅
   * If all tasks for a requirement are `[x]` → ask user if requirement should be ✅

4. Update Requirements section if new scope discovered:
   * Read ALL existing requirements first
   * Update existing rather than creating duplicates
   * Add new only if truly new scope, use next available Rn number

5. Update Context section if scope or purpose changed.

6. Write Checkpoint section:
   * 1-2 paragraph summary of work completed
   * Reference phase (if applicable) and tasks worked on
   * Include next step if decided/obvious
