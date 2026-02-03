---
name: ctx-save
description: Update project and phase docs with current state and progress
---

# Save Context

Save project state for perfect resumption by you or someone else. The level of detail here is
important so that anyone can pick up where you left off, including a junior developer.

Project files: !`claude-proj-docs`

Important: any modifications to project or phase docs need to be done via `proj-editing` skill.

## Instructions

1. Find docs: `proj/` symlink → `00-*.md` (project doc), `01-*.md` etc. (phase docs)

2. Identify current phase from Checkpoint or ask user.

3. Update **phase doc** Tasks section:
   * Mark completed tasks `[x]`
   * Add new tasks discovered during work
   * If all tasks in phase are `[x]` → ask user if phase should be ✅ (in project doc)

4. Update **phase doc** Files section:
   * If you already have full context of changes (e.g., just completed implementation), update Files directly
   * Otherwise, run `branch-diff-summarizer` agent for changed files
   * Format per @~/.claude/docs/project-doc.md

5. Update **project doc** if needed:
   * Update phase status (🔄 → ✅) after user confirmation
   * Update Requirements if new scope discovered (read ALL first, update existing)
   * Update Files section with summary of phase doc files
   * Update Context if scope or purpose changed

6. Write **project doc** Checkpoint section:
   * 1-2 paragraph summary of work completed
   * Reference current phase and tasks worked on
   * Include next step if decided/obvious
