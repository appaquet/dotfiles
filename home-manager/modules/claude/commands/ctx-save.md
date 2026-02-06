---
name: ctx-save
description: Update project and phase docs with current state and progress
---

# Save Context

Save project state for perfect resumption. Detail level should allow anyone, including a junior
intern, to pick up where you left off

Project files: !`claude-proj-docs`

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Load skills (from ~/.claude/skills/)
    * Load the `proj-editing` right away. This will be needed for updating project and phase docs
    * Ensure you fully understand structure like `<project-doc-sections>` and `<phase-doc-sections>`

3. 🔳 Find docs via `proj/` symlink. Identify current phase from Checkpoint or ask user

4. 🔳 Update phase doc using `proj-editing` skill:
   * Tasks: mark completed `[x]`, add new tasks discovered
     * If all done, confirmed via `AskUserQuestion`, update phase in next step
   * Files: update with changes
     * Use `branch-diff-summarizer` agent if needed not aware of files or may be missing some from
       your context)

5. 🔳 Update project doc using `proj-editing` skill:
   * Checkpoint
     * Update summary of work done
     * Reference current phase and tasks
     * Next step if decided/obvious
   * Requirements
     * Read current requirements carefully
     * Update or add new ones if needed based on work done
   * Questions
     * Add resolved questions if any
     * Add new questions if arose during work
   * Phases
     * Update status if all tasks completed + user confirmed done via `AskUserQuestion`
   * Files
     * Update with summary

6. 🔳 Write project doc Checkpoint:
   * 1-2 paragraph summary of work completed
   * Reference current phase and tasks worked on
   * Next step if decided/obvious
